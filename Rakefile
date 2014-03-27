require 'bundler/setup'
require 'rubydoop/package'
require 'wikipedia/vandalism_detection'
require 'csv'
require 'fileutils'

# Returns the evaluation data average value hash of the given evaluations.
def evaluation_data_of(evaluations)
  class_index = Wikipedia::VandalismDetection::Instances::VANDALISM_CLASS_INDEX
  total_count = evaluations.count.to_f

  recall = evaluations.reduce(0.0) { |result, sample| result + sample.recall(class_index) } / total_count
  precision = evaluations.reduce(0.0) { |result, sample| result + sample.precision(class_index) } / total_count
  area_under_prc = evaluations.reduce(0.0) { |result, sample| result + sample.area_under_prc(class_index) } / total_count

  { precision: precision, recall: recall, area_under_prc: area_under_prc }
end

# Packages the jobs into an executable jar file
#
# @example
#  rake package
#  rake package JAR_NAME=custom-jar-name
desc "Packages the rubydoop jobs in a jar file"
task :package do
  jar_name = ENV['JAR_NAME'] || 'wikipedia-vandalism-analyzer'
  jar_file = "#{jar_name}.jar"
  jars = Dir['lib/java/cloud9-wikipedia.jar']

  File.delete(jar_file) if File.exists?(jar_file)

  begin
    puts "packaging into #{File.dirname(__FILE__)}/build/#{jar_file} ..."

    job_package = Rubydoop::Package.new(project_name: jar_name, lib_jars: jars)
    job_package.create!
  rescue => e
    puts "Error while packaging:\n #{e.message}"
  end

  puts 'Done.'
end

namespace :build do

  # Creates a corpus index file for the configured training corpus for faster feature building
  #
  # @example
  #  rake build:corpus_index
  desc "Builds an index file for training data files. This file is used to speed up the arff file creation."
  task :corpus_index do
    Wikipedia::VandalismDetection::TrainingDataset.create_corpus_file_index!
  end

  # Creates the configured features for the configured training corpus
  #
  # @example
  #  rake build:features
  desc "Builds the configured features for the configured training data set. See conf/config.yml!"
  task :features do
    Wikipedia::VandalismDetection::TrainingDataset.build!
  end

  # Creates an additional feature for the configured training corpus.
  # The feature attribute and values are added to the arff file.
  #
  # @example
  #  rake build:additional_feature NAME=compressibility
  #  rake build:additional_feature NAME='size ratio'
  #
  desc "Builds an additional feature for the configured training data set."
  task :additional_feature do
    feature = ENV['NAME']
    index_file = Wikipedia::VandalismDetection.configuration["training_corpus"]["index_file"]
    Rake::Task['build:corpus_index'].invoke unless File.exists?(index_file)

    Wikipedia::VandalismDetection::TrainingDataset.add_feature_to_arff!(feature)
  end

  task :all_features do
    features = Wikipedia::VandalismDetection::Configuration::DEFAULTS['features']
    first = features.shift

    Wikipedia::VandalismDetection::Configuration::DEFAULTS['features'] = first
    Wikipedia::VandalismDetection::TrainingDataset.build!

    features.each do |feature|
      Wikipedia::VandalismDetection::TrainingDataset.add_feature_to_arff!(feature)
    end
  end

  # Creates PRC data for the configured classifier on the configured dataset
  #
  # @example
  #   rake build:prd_data
  #   rake build:prc_data EQUALLY_DISTRIBUTED=true
  #
  desc "Create Performance curve data (PRC) for classifier"
  task :prc_data do
    data_file = Wikipedia::VandalismDetection.configuration["training_corpus"]["arff_file"]
    Rake::Task['build:features'].invoke unless File.exists?(data_file)

    classifier = Wikipedia::VandalismDetection::Classifier.new
    equally_distributed = ENV['EQUALLY_DISTRIBUTED'] == 'true'

    source_dir = Wikipedia::VandalismDetection.configuration['source']
    evaluations_dir = "#{source_dir}/build/evaluations"
    time = Time.now.strftime("%Y-%m-%d_%H-%M-%S")
    classifier_type = Wikipedia::VandalismDetection.configuration["classifier"]["type"]

    curve = classifier.evaluator.curve_data(equally_distributed: equally_distributed)
    auprc = curve[:area_under_prc]

    FileUtils.mkdir_p(evaluations_dir) unless Dir.exists?(evaluations_dir)
    prc_file = "#{evaluations_dir}/evaluation-#{time}-#{classifier_type}-#{auprc}.csv"
    puts "saving PRC data to #{prc_file}..."

    points = (0...curve[:precision].count).map { |index| [curve[:precision][index], curve[:recall][index]] }

    CSV.open(prc_file, 'w') do |file|
      points.each do |p|
        file << p
      end
    end
  end
end

# Evaluates the configured classifier on the configured dataset
#
# @example
#   rake classifier_evaluation
#   rake classifier_evaluation EQUALLY_DISTRIBUTED=true
#
desc "Evaluates the configured classifier"
task :classifier_evaluation do
  data_file = Wikipedia::VandalismDetection.configuration["training_corpus"]["arff_file"]
  Rake::Task['build:features'].invoke unless File.exists?(data_file)

  classifier = Wikipedia::VandalismDetection::Classifier.new

  equally_distributed = ENV['EQUALLY_DISTRIBUTED'] == 'true'
  evaluations = classifier.cross_validate(equally_distributed: equally_distributed)

  if equally_distributed
    evaluation = evaluation_data_of(evaluations)
    puts "avg precision: #{evaluation[:precision]}"
    puts "avg recall: #{evaluation[:recall]}"
    puts "avg AUPRC: #{evaluation[:area_under_prc]}"
  else
    puts "classifier: #{Wikipedia::VandalismDetection.configuration["classifier"]["type"]}"
    puts "options: #{Wikipedia::VandalismDetection.configuration["classifier"]["options"] || "default"}\n"
    puts "#{evaluations.class_details}"
  end
end

# Classifies all revisions of the given wikipedia history dump file.
#
# @example
#   rake classify FILE=wikipedia-history-dump.xml
#   rake classify FILE=wikipedia-history-dump.bz2
#
desc "Classifies all revisions of the given wikipedia history dump file"
task :classify do
  file = ENV['FILE']
  file_path = File.expand_path("../#{file}", __FILE__)

  puts file_path
  raise_error("#{file_path} is not available") unless File.exists?(file_path)

  puts "parse page..."
  xml = File.read(file_path)
  parser = Wikipedia::VandalismDetection::PageParser.new
  page = parser.parse xml
  print "ready...\n"

  classifier = Wikipedia::VandalismDetection::Classifier.new

  page.edits.each do |edit|
    label = classifier.classify(edit)
    puts "#revision: #{edit.new_revision.id} is #{label}"
  end
end