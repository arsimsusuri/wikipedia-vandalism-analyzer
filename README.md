# Wikipedia Vandalism Analyzer

Rubydoop Jobs and offline scripts for Wikipedia Vandalism Detection and Analyzing.

## Setup

Make sure you:

* have the R-programming language installed (since the systems uses the rinruby-gem for plotting PR-curves)
* are using JRuby >= 1.7.10
* have Hadoop installed and added the installation directory to the `HADOOP_INSTALL` system path variable

To install Gem dependencies execute:

    $ bundle install

Add JRuby options for the Java garbage collector and used memory to prevent OutOfMemory exceptions:

    $ export JRUBY_OPTS="-J-XX:+CMSClassUnloadingEnabled -J-XX:+UseConcMarkSweepGC -J-Xmx2048m"

## Usage

### Running Rake tasks

Building the corpus file index:

    $ rake build:corpus_index

Building the training dataset ARFF file (features for corpus data):

    $ rake build:features

Add a feature to the existing ARFF file:

    # Make sure the feature to add is not yet in the config's feature list.
    $ rake build:additional_feature NAME='feature name'
    # Then add the features name to the feature list

Build the configured classifiers Precision/Recall curve data to csv file:

    $ rake build:prc_data
    # This saves an 'evaluation-<timestamp>-<classifier>-<AUPRC>.csv' file to /build/evaluation directory
    # which holds the raw precision/recall data points for plotting a curve

Evaluate the configured classifier (over all samples):

    $ rake classifier_evaluation

Evaluate the configured classifier with equally distributed (down-sampled) datasets:

    $ rake classifier_evaluation EQUALLY_DISTRIBUTED=true

Classify Wikipedia pages in xml format:

    $ rake classify FILE=file_name.xml

### Running Hadoop jobs

Available jobs are:

* feature_calculation
* classification

Running a job:

    $ hadoop jar build/<wikipedia-vandalism-analyzer>.jar jobs/<job> <input_files> <output/directory> 

Example:
    
    $ cd build
    $ haddop jar wikipedia-vandalism-analyzer.jar jobs/feature_calculation Wikipedia-history-dump.bz2 ~/rubydoop/features
    $ haddop jar wikipedia-vandalism-analyzer.jar jobs/classification ~/rubydoop/features ~/rubydoop/classification

## Contributing

1. Fork it ( http://github.com/<my-github-username>/wikipedia-vandalism_analyzer/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
