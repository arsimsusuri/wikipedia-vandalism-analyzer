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
    index_file = Wikipedia::VandalismDetection.configuration.training_corpus_index_file
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
  #   rake build:performance_data # default sample number is 100
  #   rake build:performance_data SAMPLES=150
  #
  desc "Create performance curve data (PRC & ROC) for classifier on testset"
  task :performance_data do
    sample_count = ENV['SAMPLES']
    sample_count = sample_count.to_i if sample_count

    classifier = Wikipedia::VandalismDetection::Classifier.new
    evaluator = classifier.evaluator

    puts "#{classifier.dataset.n_rows} instances in training set."

    performance_data = evaluator.evaluate_testcorpus_classification(sample_count: sample_count)

    recall_values = performance_data[:recalls]
    precision_values = performance_data[:precisions]
    fp_rate_values = performance_data[:fp_rates]
    aucpr = performance_data[:auprc].round(3)
    aucro = performance_data[:auroc].round(3)
    total_recall = performance_data[:total_recall].round(3)
    total_precision = performance_data[:total_precision].round(3)

    config = Wikipedia::VandalismDetection.configuration

    classifier_type = config.classifier_type.split('::').last.downcase
    uniform = config.uniform_training_data?
    training_type = uniform ? 'uniform' : 'all-samples'

    sub_dir = File.join(config.output_base_directory, classifier_type, training_type)
    FileUtils.mkdir_p(sub_dir)

    prc_file_name = "#{classifier_type}-prc-#{aucpr.to_s.gsub('.','')}_p#{total_precision.to_s.gsub('.','')}-r#{total_recall.to_s.gsub('.','')}.txt"
    roc_file_name = "#{classifier_type}-roc-#{aucro.to_s.gsub('.','')}_p#{total_precision.to_s.gsub('.','')}-r#{total_recall.to_s.gsub('.','')}.txt"

    # open files
    puts "working in #{config.output_base_directory}"
    prc_file = File.open(File.join(sub_dir, prc_file_name), 'w')
    roc_file = File.open(File.join(sub_dir, roc_file_name), 'w')

    sorted_prc = evaluator.sort_curve_values(recall_values, precision_values)
    sorted_roc = evaluator.sort_curve_values(fp_rate_values, recall_values)

    # write to prc file
    puts "writing #{prc_file_name}..."
    prc_x = sorted_prc[:x]
    prc_y = sorted_prc[:y]

    prc_x.each_with_index do |x, index|
      prc_file.puts [x, prc_y[index]].join(',')
    end

    # write to roc file
    puts "writing #{roc_file_name}..."
    roc_x = sorted_roc[:x]
    roc_y = sorted_roc[:y]

    roc_x.each_with_index do |x, index|
      roc_file.puts [x, roc_y[index]].join(',')
    end

    # close files
    prc_file.close
    roc_file.close

    # plotting curves
    plot_file = File.expand_path('../scripts/plot_curve', __FILE__)

    puts "plotting PR curve..."
    prc_file_path = File.join(sub_dir, prc_file_name)
    prc_output_file = File.join(sub_dir, prc_file_name.gsub('.txt', ''))
    prc_plot_title = "PRC (#{classifier_type}) | AUC = #{aucpr}, Precision = #{total_precision}, Recall = #{total_recall}"
    system "#{plot_file} #{prc_file_path} #{prc_output_file} Recall Precision '#{prc_plot_title}'"

    puts "plotting RO curve..."
    roc_file_path = File.join(sub_dir, roc_file_name)
    roc_output_file = File.join(sub_dir, roc_file_name.gsub('.txt', ''))
    roc_plot_title = "ROC (#{classifier_type}) | AUC = #{aucro}"
    system "#{plot_file}  #{roc_file_path} #{roc_output_file} 'FP Rate' 'TP Rate' '#{roc_plot_title}'"

    puts "done :)"
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