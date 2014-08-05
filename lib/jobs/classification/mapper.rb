require 'wikipedia/vandalism_detection'

module Classification

  OUTPUT_PATH = 'classification'

  class Mapper

    def initialize
      @key = Hadoop::Io::Text.new
      @value = Hadoop::Io::Text.new

      unless $classifier
        file = File.expand_path('../../../data/training-full-pan10.arff', __FILE__)
        dataset = Core::Parser.parse_ARFF(file)
        dataset.class_index = Wikipedia::VandalismDetection.configuration.features.count

        $classifier = Wikipedia::VandalismDetection::Classifier.new(dataset)
      end
    end

    def map(key, value, context)
      data = value.to_s.split("\t")
      features = data[1].split(',').map(&:to_f)
      confidence = $classifier.classify features

      @key.set data[0]
      @value.set confidence.to_s

      context.write @key, @value
    end

  end
end