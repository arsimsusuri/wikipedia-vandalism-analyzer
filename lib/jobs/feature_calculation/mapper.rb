require 'wikipedia/vandalism_detection'
require 'jobs/conditions/page_ids'
require 'saxerator'
require "parallel"

module FeatureCalculation

  OUTPUT_PATH = 'features'

  class Mapper

    def initialize
      @key = Hadoop::Io::Text.new
      @value = Hadoop::Io::Text.new

      @feature_calculator = Wikipedia::VandalismDetection::FeatureCalculator.new
      @parser = Wikipedia::VandalismDetection::PageParser.new
    end

    def map(key, value, context)
      page_id = Saxerator.parser(value.to_s).for_tag(:id).within(:page).first
      return unless Conditions::PageIds.available?(page_id)

      page = @parser.parse value.to_s
      edits = page.edits

      Parallel.each(edits) do |edit|
        features = @feature_calculator.calculate_features_for(edit)

        unless features.empty?
          key_data = [page.id, edit.old_revision.id, edit.new_revision.id, page.title]
          @key.set key_data.join(',')
          @value.set features.join(',')

          context.write @key, @value
        end
      end
    end
  end
end