require 'wikipedia/vandalism_detection'
require 'base64'
require 'zlib'

module SimpleVandalism
  module FeatureCalculation

    class Reducer

      def initialize
        @key = Hadoop::Io::Text.new
        @value = Hadoop::Io::Text.new

        @parser = Wikipedia::VandalismDetection::RevisionParser.new
        @feature_calculator = Wikipedia::VandalismDetection::FeatureCalculator.new
      end

      # Output:
      # Key: page_id, rev_id / page_id, rev_parent_id
      # Value:  zipped rev_xml, parent_rev_id, simple_vandalism / zipped rev_xml, rev_id, simple_vandalism
      #
      # Output:
      # Key: page_id
      # Value: parent_rev_id, rev_id, simple_vandalism, <features computed from text>
      def reduce(key, values, context)
        inputs = values.map(&:to_s)

        revisions = inputs.map do |input|
          compressed_xml = input.split(',').first
          xml = Zlib::Inflate.inflate(Base64.strict_decode64(compressed_xml))

          context.progress
          @parser.parse(xml)
        end

        if revisions.count == 2
          edit = nil

          begin
            edit = Wikipedia::VandalismDetection::Edit.new(revisions.first, revisions.last)
            simple_vandalism = inputs.last.to_s.split(',').last
          rescue
            edit = Wikipedia::VandalismDetection::Edit.new(revisions.last, revisions.first)
            simple_vandalism = inputs.first.to_s.split(',').last
          end

          features = @feature_calculator.calculate_features_for(edit)

          @key.set key.to_s.split(',').first
          @value.set [edit.old_revision.id, edit.new_revision.id, simple_vandalism, *features].join(',')

          context.write(@key, @value)
        end
      end
    end
  end
end