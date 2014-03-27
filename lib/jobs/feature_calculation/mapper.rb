require 'wikipedia/vandalism_detection'

module FeatureCalculation
  class Mapper

    def initialize
      @key = Hadoop::Io::Text.new
      @value = Hadoop::Io::Text.new

      @feature_calculator = Wikipedia::VandalismDetection::FeatureCalculator.new
      @parser = Wikipedia::VandalismDetection::PageParser.new
    end

    def map(key, value, context)
      page = @parser.parse value.to_s

      page.edits.each do |edit|
        features = @feature_calculator.calculate_features_for(edit)

        unless features.empty?
          @key.set edit.new_revision.id
          @value.set features.join(',')

          context.write @key, @value
        end
      end
    end
  end
end