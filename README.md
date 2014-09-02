# Wikipedia Vandalism Analyzer

Rubydoop Jobs and offline scripts for Wikipedia Vandalism Detection and Analyzing.

## Setup

Make sure you:

* have gnuplot installed (since the systems uses the gnuplot for plotting curves)
* are using JRuby >= 1.7.10
* have Hadoop installed and added the installation directory to the `HADOOP_INSTALL` system path variable

To install Gem dependencies execute:

    $ bundle install
    
Since the used ruby-band gem saves its required jar files to a global directory, these jars are not available when packaging 
the `wikipedia-vandalism-analyzer.jar` which is used to run hadoop jobs. Thus, we use a modified version of the gem 
(see [https://github.com/paulgoetze/ruby-band/tree/develop](https://github.com/paulgoetze/ruby-band/tree/develop)). To include the needed jar files, 
make sure to go to the gems installation directory and run `rake install`.  
This will create a `jars` directory in the gem's `lib/` directory comprising all needed jars.

In case of heap errors, try adding JRuby options for the Java garbage collector and used memory to prevent OutOfMemory exceptions:

    $ export JRUBY_OPTS="-J-XX:+CMSClassUnloadingEnabled -J-XX:+UseConcMarkSweepGC -J-Xmx2048m"

## Usage

### Configuration

Put a `config.yml` file to `config/` or `lib/config/` directory.
For further configuration options see part *Configuration* in 
[`wikipedia-vandalism_detection`](https://github.com/webis-de/wikipedia-vandalism-detection) gem README.md!

An example config file content could be:

    corpora:
          base_directory: /home/user/corpora

          training:
            base_directory: training
            annotations_file: annotations.csv
            edits_file: edits.csv
            revisions_directory: revisions

          test:
            base_directory: test
            edits_file: edits.csv
            revisions_directory: revisons

        output:
          base_directory: /home/user/output_path
          training:
            arff_file: training.arff
            index_file: training_index.yml
          test:
            arff_file: test.arff
            index_file: test_index.yml

    features:
          - anonymity
          - biased frequency
          - character sequence

    classifier:
          type: Trees::RandomForest     # Weka classifier
          options: -I 100               # for further classifier options rrefer to Weka-dev documentation
          cross-validation-fold: 10
          uniform-training-data: false

### Running Rake tasks

**Building the corpus file index:**

    $ rake build:corpus_index

**Building the training and test dataset ARFF file (features for corpus data):**

    $ rake build:training_features
    $ rake build:test_features

**Build the configured classifiers performance curve data and plots (PR-curve and ROC-curve):**

    $ rake build:performance_data

This creates all needed data (index and ARFF files) for configured features from `config.yml` implicitly
(Attention! It can be very time consuming to compute all features!).
 Perfromance curves are plottet to subdirectories of the output base directory.

 *Example:*

 - for classifier `Trees:RandomForest` using all samples it will save plots and curve files to
 `<output_base_directory>/randomforest/all-samples/`
 - for classifier `Trees:RandomForest` using uniform distributed training set it will save plots and curve files to
    `<output_base_directory>/randomforest/uniform/`
    
**Building prediction analysis data for configured features:**

    $ rake build:feature_analysis
    
This task creates csv-files with each feature's prediction data. These files are used in the 
`build:feature_analysis_plots` task.
    
**Plotting the feature analysis data to pdf curve files:**
 
    $ rake build:feature_analysis_plots
    
This rake task produces gnuplot plots as cropped pdf files. Curves are created for absolute and normalized 
prediction data. This task runs the `build:feature_analysis` task if the data is not yet avaliable.

**Evaluate the configured classifier (over all samples):**

    $ rake classifier_evaluation

**Evaluate the configured classifier with equally distributed (down-sampled) datasets:**

    $ rake classifier_evaluation EQUALLY_DISTRIBUTED=true

**Classify Wikipedia pages in xml format:**

    $ rake classify FILE=file_name.xml

### Running Hadoop jobs

Available jobs are:

* feature_calculation
* classification_with_existing_features (needs the data of the feature_calculation job)
* full_classification (first two jobs combined in one)
* simple_vandalism_features_calculation_map
* simple_vandalism_features_calculation_red
* simple_vandalism_features_calculation (the two jobs above combined in one)
* simple_vandalism_mapred_count_per_page
* simple_vandalism_red_count_per_page
* simple_vandalism_extract_edits (the two above jobs combined in one)

The `simple_vandalism_features_...` jobs run on a revision basis (one revision tag xml content per map).  
The last three `simple_vandalism_...` jobs run on a full page basis (High heap memory use!).

Running a job:

    $ hadoop jar build/<wikipedia-vandalism-analyzer>.jar jobs/<job> <input_files> <output/directory> 

Example:
    
    $ cd build
    $ haddop jar wikipedia-vandalism-analyzer.jar jobs/feature_calculation Wikipedia-history-dump.bz2 ~/results/features
    $ haddop jar wikipedia-vandalism-analyzer.jar jobs/classification ~/rubydoop/features ~/results/classification

## Contributing

1. Fork it ( http://github.com/webis-de/wikipedia-vandalism-analyzer/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
