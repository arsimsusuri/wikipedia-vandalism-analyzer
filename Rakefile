require 'bundler/setup'
require 'rubydoop/package'
require 'wikipedia/vandalism_detection'
require_relative './lib/wikipedia/vandalism_analyzer/arff_file_creator'
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

  src_path = File.expand_path("../data", __FILE__)
  dest_path = File.expand_path("../lib", __FILE__)

  begin
    print "\ncopying needed files..."
    FileUtils.cp_r(src_path, dest_path)
    print "done"

    puts "\npackaging into #{File.dirname(__FILE__)}/build/#{jar_file} ..."

    job_package = Rubydoop::Package.new(project_name: jar_name, lib_jars: jars)
    job_package.create!
  rescue => e
    puts "Error while packaging:\n #{e.message}"
  ensure
    FileUtils.rm_r(File.join(dest_path, 'data'))
  end

  puts 'done'
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
    Wikipedia::VandalismDetection::TrainingDataset.build
  end

  # Creates the configured features for the configured test corpus
  #
  # @example
  #  rake build:test_features
  desc "Builds the configured features for the configured test data set. See conf/config.yml!"
  task :test_features do
    Wikipedia::VandalismDetection::TestDataset.build
  end

  # Creates the configured training corpus
  #
  # @example
  #   rake build:training_corpus FILE=/home/user1/datasets/training.arff
  #
  desc "Builds the configured training corpus. See conf/config.yml!"
  task :training_corpus do
    file = ENV['FILE'] || File.expand_path("../build/training-data.arff", __FILE__)
    config = Wikipedia::VandalismDetection.configuration

    if config.balanced_training_data?
      puts "building BALANCED training dataset"
      dataset = Wikipedia::VandalismDetection::TrainingDataset.balanced_instances
    elsif config.unbalanced_training_data?
      puts "building FULL (unbalanced) training dataset"
      dataset = Wikipedia::VandalismDetection::TrainingDataset.instances
    elsif config.oversampled_training_data?
      puts "building OVERSAMPLED training dataset"
      dataset = Wikipedia::VandalismDetection::TrainingDataset.oversampled_instances
    end

    dataset.to_ARFF(file)
  end

  # Creates the configured test corpus
  #
  # @example
  #  rake build:test_corpus FILE=/home/user1/dataset/test.arff
  #
  desc "Builds the configured test corpus. See conf/config.yml!"
  task :test_corpus do
    file = ENV['FILE'] || File.expand_path("../build/test-data.arff", __FILE__)
    dataset = Wikipedia::VandalismDetection::TestDataset.build

    dataset.to_ARFF(file)
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
    sub_dir = File.dirname(config.test_output_classification_file)
    FileUtils.mkdir_p(sub_dir)

    # save training dataset
    classifier.dataset.to_ARFF(config.training_output_arff_file)

    classifier_type = config.classifier_type.split('::').last.downcase
    prc_file_name = "#{classifier_type}-pr-#{pr_auc.to_s.gsub('.','')}_p#{total_precision.to_s.gsub('.','')}-r#{total_recall.to_s.gsub('.','')}.txt"
    rocc_file_name = "#{classifier_type}-roc-#{roc_auc.to_s.gsub('.','')}_p#{total_precision.to_s.gsub('.','')}-r#{total_recall.to_s.gsub('.','')}.txt"

    # open files
    puts "working in #{sub_dir}"
    prc_file = File.open(File.join(sub_dir, prc_file_name), 'w')
    rocc_file = File.open(File.join(sub_dir, rocc_file_name), 'w')

    # write to prc file
    puts "writing #{prc_file_name}..."

    recall_values.each_with_index do |x, index|
      prc_file.puts [x, precision_values[index]].join(',')
    end

    # write to roc file
    puts "writing #{rocc_file_name}..."

    fp_rate_values.each_with_index do |x, index|
      rocc_file.puts [x, recall_values[index]].join(',')
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

    puts "plotting ROC curve..."
    rocc_file_path = File.join(sub_dir, rocc_file_name)
    rocc_output_file = File.join(sub_dir, rocc_file_name.gsub('.txt', ''))
    rocc_plot_title = "ROC (#{classifier_type}) | AUC = #{roc_auc}"
    system "#{plot_file}  #{rocc_file_path} #{rocc_output_file} 'FP Rate' 'TP Rate' '#{rocc_plot_title}'"

    puts "saving classification logs..."

    vandalism_class_index = Wikipedia::VandalismDetection::Instances::VANDALISM_CLASS_INDEX
    regular_class_index = Wikipedia::VandalismDetection::Instances::REGULAR_CLASS_INDEX

    training_dataset = classifier.dataset

    training_vandalism_count = training_dataset.enumerate_instances.reduce(0) do |count, instance|
      count += 1 if (instance.class_value.to_i == vandalism_class_index)
      count
    end

    training_regular_count = training_dataset.enumerate_instances.reduce(0) do |count, instance|
      count += 1 if (instance.class_value.to_i == regular_class_index)
      count
    end

    test_dataset = Core::Parser.parse_ARFF(config.test_output_arff_file)
    test_dataset.class_index = config.features.count

    log_file = File.join(sub_dir, 'classification.log')
    File.open(log_file, 'w') do |f|
      f.puts Time.now
      f.puts "Training dataset:"
      f.puts "\tall #{training_dataset.n_rows}"
      f.puts "\tvandalism #{training_vandalism_count} (#{ ((100.0 * training_vandalism_count) / training_dataset.n_rows.to_f).round(2) } %)"
      f.puts "\tregular #{training_regular_count} (#{ ((100.0 * training_regular_count) / training_dataset.n_rows.to_f).round(2) } %)"

      f.puts "\nTest dataset:"
      f.puts "\tall #{test_dataset.n_rows}"

      f.puts "\nUsed configuration:\n"
      f.puts config.data.to_s
    end

    puts "\ndone"
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
    subdir_name = config.uniform_training_data? ? 'feature_analysis_balanced' : 'feature_analysis_unbalanced'
    path = File.join(config.output_base_directory, classifier_name, subdir_name)

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
    subdir_name = config.uniform_training_data? ? 'feature_analysis_balanced' : 'feature_analysis_unbalanced'
    path = File.join(config.output_base_directory, classifier_name, subdir_name)
    output_path = File.join(path, 'plots')

    FileUtils.mkdir_p(output_path) unless Dir.exists?(output_path)
    Rake::Task['build:feature_analysis'].invoke if (Dir[File.join(path, "*.csv")].count == 0)

    # plotting curves
    Dir[File.join(path, "*.csv")].each do |file|
      plot_file = File.expand_path('../scripts/plot_feature_analysis', __FILE__)

      puts "plotting data of '#{File.basename(file)}'"
      feature_name = File.basename(file).gsub('.csv', '')
      output_file_path = File.join(output_path, feature_name)

      plot_title = "prediction analysis: #{feature_name.gsub('normalized_', '')} (#{classifier_name})"
      x_label = 'Threshold'
      y_label = (file =~ /normalized/) ? 'Number of instances (normalized to 1)' : 'Number of instances'

      system "'#{plot_file}' '#{file}' '#{output_file_path}' '#{x_label}' '#{y_label}' '#{plot_title}'"
    end

    puts "done :)"
  end

  # Builds the full classifier prediction data analysis
  #
  # @example
  #   rake build:classifier_analysis
  desc "Creates analysis files similar to feature analysis tasl but for full combined feature set"
  task :classifier_analysis do
    dataset = Wikipedia::VandalismDetection::Instances.empty_for_feature('anonymity')
    10.times{ dataset.add_instance([1.0, Wikipedia::VandalismDetection::Instances::REGULAR]) }

    classifier = Wikipedia::VandalismDetection::Classifier.new(dataset)
    sample_count = ENV['SAMPLES']
    sample_count = sample_count.to_i if sample_count

    config = Wikipedia::VandalismDetection.configuration
    classifier_name = config.classifier_type.split('::').last.downcase
    subdir_name = "feature_analysis_#{config.training_data_options}"
    path = File.join(config.output_base_directory, classifier_name, subdir_name, 'all')

    FileUtils.mkdir_p(path) unless Dir.exists?(path)
    analysis_bin_file = File.join(path, 'full_analysis_hash')

    if File.exists?(analysis_bin_file)
      puts "loading binary full analysis file"
      analysis = Marshal.load(File.binread(analysis_bin_file))
    else
      analysis = classifier.evaluator.full_analysis(sample_count: sample_count)

      File.open(analysis_bin_file,'wb') do |f|
        f.write Marshal.dump(analysis)
      end
    end

    # write absolute csv file
    file_path = File.join(path, "full_feature_set.csv")

    file = File.open(file_path, 'w')
    header = ['Threshold', 'TP', 'TN', 'FP', 'FN'].join(',')
    file.puts header

    analysis.each do |threshold, values|
      file.puts [threshold, values[:tp], values[:tn], values[:fp], values[:fn]].join(',')
    end

    file.close

    # normalize data for TP/FN & TN/FP
    # f1: {0.0 => ..., 0.1 => ...}
    # f2: {0.0 => ..., 0.1 => ...}
    # f3: {0.0 => ..., 0.1 => ...}

    # find max(max(TP), max(FN)) -> devide all TP and FN
    # find max(max(TN), max(FP)) -> devide all TN and FP

    max_tp_fn = analysis.reduce(0.0) do |result, data|
      max = [data[1][:tp], data[1][:fn]].max
      result = (result < max) ? max.to_f : result
    end

    max_tn_fp = analysis.reduce(0.0) do |result, data|
      max = [data[1][:tn], data[1][:fp]].max
      result = (result < max) ? max.to_f : result
    end

    threshold_hash = analysis.map do |threshold, prediction_data|
      tp = prediction_data[:tp] / max_tp_fn
      fn = prediction_data[:fn] / max_tp_fn
      tn = prediction_data[:tn] / max_tn_fp
      fp = prediction_data[:fp] / max_tn_fp

      [threshold, { tp: tp, fn: fn, tn: tn, fp: fp }]
    end

    normalized_analysis = Hash[threshold_hash]

    # write normalized data to files
    file_path = File.join(path, "normalized_full_feature_set.csv")

    file = File.open(file_path, 'w')
    header = ['Threshold', 'TP', 'TN', 'FP', 'FN'].join(',')
    file.puts header

    normalized_analysis.each do |threshold, values|
      file.puts [threshold, values[:tp], values[:tn], values[:fp], values[:fn]].join(',')
    end

    file.close
  end

  # Creates a pdf plot for classifier with all configured features
  #
  # @example
  #   rake classifier_analysis_plots
  #
  desc "Creates pdf plots for classifier/full features set analysis"
  task :classifier_analysis_plots do
    config = Wikipedia::VandalismDetection.configuration
    classifier_name = config.classifier_type.split('::').last.downcase
    subdir_name = "feature_analysis_#{config.training_data_options}"
    output_path = File.join(config.output_base_directory, classifier_name, subdir_name, 'all')


    FileUtils.mkdir_p(output_path) unless Dir.exists?(output_path)
    Rake::Task['build:classifier_analysis'].invoke if (Dir[File.join(output_path, "*.csv")].count == 0)

    # plotting curves
    Dir[File.join(output_path, "*.csv")].each do |file|
      plot_file = File.expand_path('../scripts/plot_feature_analysis', __FILE__)

      puts "plotting data of '#{File.basename(file)}'"
      feature_name = File.basename(file).gsub('.csv', '')
      output_file_path = File.join(output_path, feature_name)

      plot_title = "prediction analysis: #{feature_name.gsub('normalized_', '').gsub('_', ' ')} (#{classifier_name})"
      x_label = 'Threshold'
      y_label = (file =~ /normalized/) ? 'Number of instances (normalized to 1)' : 'Number of instances'

      system "'#{plot_file}' '#{file}' '#{output_file_path}' '#{x_label}' '#{y_label}' '#{plot_title}'"
    end

    puts "done :)"
  end

  # Creates files with FN and FP edit data from classification file.
  # The threshold can be set by using the T param for the rake task.
  #
  # @example
  #   rake build:edit_error_analysis T=0.7
  #
  desc "Creates files with FN and FP edit data from classification file"
  task :edit_error_analysis do
    config = Wikipedia::VandalismDetection.configuration
    classification_file = config.test_output_classification_file

    Rake::Task['build:classifier_analysis'].invoke unless File.exists?(classification_file)

    threshold = ENV['T'] || 0.5

    path = File.join(File.dirname(classification_file), 'edit_error_analysis')
    FileUtils.mkdir_p(path) unless Dir.exists?(path)

    fn_file_name = "fn_#{threshold}.csv"
    fp_file_name = "fp_#{threshold}.csv"
    fn_diff_file_name = "fn_#{threshold}-diffs.txt"
    fp_diff_file_name = "fp_#{threshold}-diffs.txt"

    fn_file = File.open(File.join(path, fn_file_name), 'w')
    fp_file = File.open(File.join(path, fp_file_name), 'w')
    fn_diff_file = File.open(File.join(path, fn_diff_file_name), 'w')
    fp_diff_file = File.open(File.join(path, fp_diff_file_name), 'w')

    puts "writing TP and FP edit data files..."

    File.readlines(classification_file).each_with_index do |line, index|
      line = line.split.join(',')

      if index == 0
        fn_file.puts line
        fp_file.puts line
        next
      end

      values = line.split(',')

      old_id = values[0]
      new_id = values[1]
      target_class = values[2] # C column
      confidence = values[3] # CONF column

      is_fn = Wikipedia::VandalismDetection::Evaluator.false_negative?(target_class, confidence, threshold)
      is_fp = Wikipedia::VandalismDetection::Evaluator.false_positive?(target_class, confidence, threshold)

      if is_fn || is_fp
        print "\rwriting inserted and removed text for (#{old_id}, #{new_id})..."

        edit = Wikipedia::VandalismDetection::TestDataset.edit(old_id, new_id)
        return unless edit

        if is_fn
          fn_file.puts line

          fn_diff_file.puts "old rev id: #{old_id}, new rev id: #{new_id}\n"
          fn_diff_file.puts "- comment: #{edit.new_revision.comment}"
          fn_diff_file.puts "- inserted text:"
          fn_diff_file.puts "#{edit.inserted_text}\n"
          fn_diff_file.puts "- removed text:"
          fn_diff_file.puts "#{edit.removed_text}\n\n"
          fn_diff_file.puts "***********************************************************************\n\n"
        elsif is_fp
          fp_file.puts line

          fp_diff_file.puts "old rev id: #{old_id}, new rev id: #{new_id}\n"
          fp_diff_file.puts "- comment: #{edit.new_revision.comment}"
          fp_diff_file.puts "- inserted text:"
          fp_diff_file.puts "#{edit.inserted_text}\n"
          fp_diff_file.puts "- removed text:"
          fp_diff_file.puts "#{edit.removed_text}\n\n"
          fp_diff_file.puts "***********************************************************************\n\n"
        end
      end
    end

    fn_file.close
    fp_file.close
    fn_diff_file.close
    fp_diff_file.close

    puts 'done'
  end

  desc "Creates arff files from the resulting files of 'jobs/simple_vandalism_feature_calculation'."
  task :arff_files_from_job_results do
    src_dir = ENV['INPUT_DIR'] || raise(ArgumentError, "Please define a file to convert as first parameter:\nINPUT_DIR=/src-file/part-m-00000")
    dst_dir = ENV['OUTPUT_DIR'] || raise(ArgumentError, "Please define the dest dir as second parameter:\n OUTPUT_DIR=/src-file//dest-dir/")

    FileUtils.mkdir_p(dst_dir)

    @info_file = File.open(File.join(dst_dir, 'article-info.csv'), 'w')
    @info_file.puts "page_id,simple_vandalism_count,regular_count"

    src_files = Dir[File.join(src_dir, '*')].select { |f| f =~ /(part-.-\d+$)/}

    @creator = nil
    @skipped_file = false
    @written_headers = {}
    @arff_info = {}

    src_files.each_with_index do |src_file_path, file_index|
      begin
        new_page = true
        previous_page_id = nil

        lines = File.read(src_file_path).lines

        lines.each_with_index do |line, index|
          data = line.split("\t")
          current_page_id = data[0]

          new_page = !(previous_page_id && current_page_id == previous_page_id)
          print "\r processed #{ ((100.0 * (file_index + 1)) / src_files.count).round(1) }%" if new_page

          if (@creator && new_page && !@skipped_file) || index == lines.count - 1
            vandalism =
            @arff_info[current_page_id]
          end

          title = current_page_id

          if title !~ /(talk:|category:)/i # only articles
            if new_page
              arff = File.open(File.join(dst_dir, "page-#{current_page_id}.arff"), 'a')
              @creator = ArffCreator.new(arff)

              if !@written_headers[current_page_id]
                @creator.write_header(data)
                @written_headers[current_page_id] = true
                @arff_info[current_page_id] = { v: 0, r: 0 }
              else
                @creator.page_info = data[0]
              end
            end

            @creator.write_data(data[1])
            @skipped_file = false
          else
            @skipped_file = true
          end

          previous_page_id = current_page_id
        end
      rescue => e
        puts "Error: file '#{File.basename(src_file_path)}' cannot be converted.\n#{e}"
        next
      end
    end

    @info_file.close
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

desc "Classifies a full arff and saves the features with the calculated confidence to a defined file."
task :classify_arff do
  training_file = ENV['TRAINING_FILE'] || raise(ArgumentError, "Please define an TRAINING_FILE parameter.")
  input_dir = ENV['INPUT_DIR'] || raise(ArgumentError, "Please define an INPUT_DIR parameter.")
  output_dir = ENV['OUTPUT_DIR'] || raise(ArgumentError, "Please define an OUTPUT_DIR parameter.")

  raise "Training file #{training_file} not found." unless File.exist?(training_file)
  raise "Input dir #{input_dir} not found." unless Dir.exist?(input_dir)

  arff_files = Dir[File.join(input_dir, "*.arff")]
  raise "No .arff files available in #{input_dir}." if arff_files.empty?

  training_dataset = Core::Parser::parse_ARFF(training_file)
  training_dataset.class_index = training_dataset.n_col - 1
  classifier = Wikipedia::VandalismDetection::Classifier.new(training_dataset)

  FileUtils.mkdir_p(output_dir) unless Dir.exists?(output_dir)

  arff_files.each_with_index do |input_file, current_file_index|
    test_dataset = Core::Parser::parse_ARFF(input_file)
    instances_count = test_dataset.n_rows

    output_file = File.join(output_dir, 'classification-' + File.basename(input_file).gsub('arff', 'txt'))
    puts "\nprocessing file #{current_file_index + 1 }/#{arff_files.count} (#{File.basename(input_file)})..."

    File.open(output_file, 'w') do |file|
      test_dataset.to_a2d.each_with_index do |instance, index|
        features = instance[0...-1]

        confidence = classifier.classify(features).round(6)
        data = [*(instance.map { |i| i.to_f.nan? ? '?' : i }), confidence].join(',')

        file.puts data

        print "\r classifying #{((100.0 * index + 1) / instances_count).ceil.to_i} %\t"
      end
    end
  end

  puts "done"
end

desc "Collects vandalism feature values with a threshold > T and saves them to the ouput file"
task :collect_vandalism_features do
  threshold = ENV['T'].to_f || ENV['THRESHOLD'].to_f || raise(ArgumentError, "Please define a THRESHOLD (or T) parameter.")
  input_file = ENV['INPUT_FILE'] || raise(ArgumentError, "Please define an INPUT_FILE parameter.")
  output_file = ENV['OUTPUT_FILE'] || raise(ArgumentError, "Please define an OUTPUT_FILE parameter.")

  file_split = File.basename(output_file).split('.')
  output_file = File.join(File.dirname(output_file), file_split.first + "-#{threshold}." + file_split.last)

  raise "Input file #{input_file} not found." unless File.exist?(input_file)
  raise(ArgumentError, "THRESHOLD must be a value between 0.0 and 1.0") if threshold < 0.0 || threshold > 1.0

  File.open(output_file, 'w') do |output|
    input_lines = File.readlines(input_file)

    input_lines.each_with_index do |line, index|
      data = line.split(',')
      confidence = data.last.to_f
      class_value = data[-2]

      print "\r processing... #{((100.0 * index + 1) / input_lines.count).ceil.to_i} %\t"

      if class_value == Wikipedia::VandalismDetection::Instances::VANDALISM && confidence >= threshold
        output.puts [*data[0...-2], 'vandalism'].join(',')
      end
    end

    print "done\n"
  end
end
