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
  #  rake build:training_features
  desc "Builds the configured features for the configured training data set. See conf/config.yml!"
  task :training_features do
    Wikipedia::VandalismDetection::TrainingDataset.build!
  end

  # Creates the configured features for the configured test corpus
  #
  # @example
  #  rake build:test_features
  desc "Builds the configured features for the configured test data set. See conf/config.yml!"
  task :test_features do
    Wikipedia::VandalismDetection::TestDataset.build!
  end

  # Creates PRC data for the configured classifier on the configured dataset
  #
  # @example
  #   rake build:performance_data # default sample number is 100
  #   rake build:performance_data SAMPLES=150
  #
  desc "Create performance curve data (PR & ROC curves) for classifier on testset"
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
    pr_auc = performance_data[:pr_auc].round(3)
    roc_auc = performance_data[:roc_auc].round(3)
    total_recall = performance_data[:total_recall].round(3)
    total_precision = performance_data[:total_precision].round(3)

    config = Wikipedia::VandalismDetection.configuration

    classifier_type = config.classifier_type.split('::').last.downcase
    uniform = config.uniform_training_data?
    training_type = uniform ? 'uniform' : 'all-samples'

    sub_dir = File.join(config.output_base_directory, classifier_type, training_type)
    FileUtils.mkdir_p(sub_dir)

    prc_file_name = "#{classifier_type}-pr-#{pr_auc.to_s.gsub('.','')}_p#{total_precision.to_s.gsub('.','')}-r#{total_recall.to_s.gsub('.','')}.txt"
    rocc_file_name = "#{classifier_type}-roc-#{roc_auc.to_s.gsub('.','')}_p#{total_precision.to_s.gsub('.','')}-r#{total_recall.to_s.gsub('.','')}.txt"

    # open files
    puts "working in #{config.output_base_directory}"
    prc_file = File.open(File.join(sub_dir, prc_file_name), 'w')
    rocc_file = File.open(File.join(sub_dir, rocc_file_name), 'w')

    sorted_prc = evaluator.sort_curve_values(recall_values, precision_values)
    sorted_rocc = evaluator.sort_curve_values(fp_rate_values, recall_values)

    # write to prc file
    puts "writing #{prc_file_name}..."
    prc_x = sorted_prc[:x]
    prc_y = sorted_prc[:y]

    prc_x.each_with_index do |x, index|
      prc_file.puts [x, prc_y[index]].join(',')
    end

    # write to roc file
    puts "writing #{rocc_file_name}..."
    rocc_x = sorted_rocc[:x]
    rocc_y = sorted_rocc[:y]

    rocc_x.each_with_index do |x, index|
      rocc_file.puts [x, rocc_y[index]].join(',')
    end

    # close files
    prc_file.close
    rocc_file.close

    # plotting curves
    plot_file = File.expand_path('../scripts/plot_curve', __FILE__)

    puts "plotting PR curve..."
    prc_file_path = File.join(sub_dir, prc_file_name)
    prc_output_file = File.join(sub_dir, prc_file_name.gsub('.txt', ''))
    prc_plot_title = "PR (#{classifier_type}) | AUC = #{pr_auc}, Precision = #{total_precision}, Recall = #{total_recall}"
    system "#{plot_file} #{prc_file_path} #{prc_output_file} Recall Precision '#{prc_plot_title}'"

    puts "plotting RO curve..."
    rocc_file_path = File.join(sub_dir, rocc_file_name)
    rocc_output_file = File.join(sub_dir, rocc_file_name.gsub('.txt', ''))
    rocc_plot_title = "ROC (#{classifier_type}) | AUC = #{roc_auc}"
    system "#{plot_file}  #{rocc_file_path} #{rocc_output_file} 'FP Rate' 'TP Rate' '#{rocc_plot_title}'"

    puts "done :)"
  end

  desc "Creates prediction value analysis files of all configured features for configured classifier."
  task :feature_analysis do
    dataset = Wikipedia::VandalismDetection::Instances.empty_for_feature('anonymity')
    10.times{ dataset.add_instance([1.0, Wikipedia::VandalismDetection::Instances::REGULAR]) }

    classifier = Wikipedia::VandalismDetection::Classifier.new(dataset)
    sample_count = ENV['SAMPLES']
    sample_count = sample_count.to_i if sample_count

    config = Wikipedia::VandalismDetection.configuration
    classifier_name = config.classifier_type.split('::').last.downcase
    path = File.join(config.output_base_directory, classifier_name, 'feature_analysis')

    FileUtils.mkdir_p(path) unless Dir.exists?(path)
    analysis_bin_file = File.join(path, 'analysis_hash')

    if File.exists?(analysis_bin_file)
      puts "loading binary analysis file"
      analysis = Marshal.load(File.binread(analysis_bin_file))
    else
      analysis = classifier.evaluator.feature_analysis(sample_count: sample_count)

      File.open(analysis_bin_file,'wb') do |f|
        f.write Marshal.dump(analysis)
      end
    end

    # write data to files
    analysis.each do |feature_name, feature_data|
      feature_name = feature_name.gsub(' ', '_').downcase
      file_path = File.join(path, "#{feature_name}.csv")

      file = File.open(file_path, 'w')
      header = ['Threshold', 'TP', 'TN', 'FP', 'FN'].join(',')
      file.puts header

      feature_data.each do |threshold, values|
        file.puts [threshold, values[:tp], values[:tn], values[:fp], values[:fn]].join(',')
      end

      file.close
    end

    # normalize data for TP/FN & TN/FP
    # f1: {0.0 => ..., 0.1 => ...}
    # f2: {0.0 => ..., 0.1 => ...}
    # f3: {0.0 => ..., 0.1 => ...}

    # find max(max(TP), max(FN)) -> devide all TP and FN
    # find max(max(TN), max(FP)) -> devide all TN and FP

    temp_analysis = analysis.map do |feature, threshold_data|
      max_tp_fn = threshold_data.reduce(0.0) do |result, data|
        max = [data[1][:tp], data[1][:fn]].max
        result = (result < max) ? max.to_f : result
      end

      max_tn_fp = threshold_data.reduce(0.0) do |result, data|
        max = [data[1][:tn], data[1][:fp]].max
        result = (result < max) ? max.to_f : result
      end

      threshold_hash = threshold_data.map do |threshold, prediction_data|
        tp = prediction_data[:tp] / max_tp_fn
        fn = prediction_data[:fn] / max_tp_fn
        tn = prediction_data[:tn] / max_tn_fp
        fp = prediction_data[:fp] / max_tn_fp
        [threshold, { tp: tp, fn: fn, tn: tn, fp: fp }]
      end

      [feature, Hash[threshold_hash]]
    end

    normalized_analysis = Hash[temp_analysis]

    # write normalized data to files
    normalized_analysis.each do |feature_name, feature_data|
      feature_name = feature_name.gsub(' ', '_').downcase
      file_path = File.join(path, "normalized_#{feature_name}.csv")

      file = File.open(file_path, 'w')
      header = ['Threshold', 'TP', 'TN', 'FP', 'FN'].join(',')
      file.puts header

      feature_data.each do |threshold, values|
        file.puts [threshold, values[:tp], values[:tn], values[:fp], values[:fn]].join(',')
      end

      file.close
    end
  end

  # Creates pdf plots for configured features
  #
  # @example
  #   rake feature_analysis_plots
  #
  desc "Creates pdf plots for each features analysis data"
  task :feature_analysis_plots do
    config = Wikipedia::VandalismDetection.configuration
    classifier_name = config.classifier_type.split('::').last.downcase
    path = File.join(config.output_base_directory, classifier_name, 'feature_analysis')
    output_path = File.join(path, 'plots')

    FileUtils.mkdir_p(output_path) unless Dir.exists?(output_path)
    Rake::Task['build:feature_analysis'].invoke if (Dir[File.join(path, "*.csv")].count == 0)

    # plotting curves
    Dir[File.join(path, "*.csv")].each do |file|
      plot_file = File.expand_path('../scripts/plot_feature_analysis', __FILE__)

      puts "plotting data of '#{File.basename(file)}'"
      feature_name = File.basename(file).gsub('.csv', '')
      output_file_path = File.join(output_path, feature_name)

      plot_title = "prediction analysis: #{feature_name} (#{classifier_name})"
      x_label = 'Threshold'
      y_label = file =~ 'normalized' ? 'Number of instances (normalized to 1)' : 'Number of instances'

      system "'#{plot_file}' '#{file}' '#{output_file_path}' '#{x_label}' '#{y_label}' '#{plot_title}'"
    end

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
  data_file = Wikipedia::VandalismDetection.configuration.training_corpus_arff_file
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
    puts "classifier: #{Wikipedia::VandalismDetection.configuration.classifier_type}"
    puts "options: #{Wikipedia::VandalismDetection.configuration.classifier_options || "default"}\n"
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