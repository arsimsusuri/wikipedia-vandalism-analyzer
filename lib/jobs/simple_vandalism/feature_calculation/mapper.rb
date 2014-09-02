require 'wikipedia/vandalism_detection'
require 'jobs/conditions/revision_ids'
require 'saxerator'
require 'base64'
require 'zlib'

module SimpleVandalism
  module FeatureCalculation

    class Mapper

      def initialize
        @key = Hadoop::Io::Text.new
        @value = Hadoop::Io::Text.new

        @parser = Wikipedia::VandalismDetection::RevisionParser.new
      end

      # Output:
      # Key: page_id, rev_id / page_id, rev_parent_id
      # Value:  zipped rev_xml, parent_rev_id, simple_vandalism / zipped rev_xml, rev_id, simple_vandalism
      def map(key, value, context)
        revision_id = Saxerator.parser(value.to_s).for_tag(:id).within(:revision).first
        data = Conditions::RevisionIds.data_for_revision(revision_id)

        return unless data # do not write to context for other revisions than defined in revisions.csv

        revision = @parser.parse(value.to_s, only: [:id, :parent_id])

        page_id = data['page_id']
        simple_vandalism = data['simple_vandalism']
        old_revision_id = revision.parent_id
        new_revision_id = revision.id
        zipped_value = Base64.strict_encode64(Zlib::Deflate.deflate(value.to_s))

        if !old_revision_id.to_s.empty?
          # for old revision of edit
          @key.set [page_id, old_revision_id].join(',')
          @value.set [zipped_value, simple_vandalism].join(',')
          context.write(@key, @value)
        end

        # for new revision of edit
        @key.set [page_id, new_revision_id].join(',')
        @value.set [zipped_value, simple_vandalism].join(',')
        context.write(@key, @value)
      end
    end
  end
end