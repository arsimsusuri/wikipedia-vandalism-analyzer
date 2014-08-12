require 'wikipedia/vandalism_detection'
require 'jobs/conditions/page_ids'
require 'saxerator'
require 'parallel'

module SimpleVandalism

  class Mapper

    def initialize
      @key = Hadoop::Io::Text.new
      @value = Hadoop::Io::Text.new
      @parser = Wikipedia::VandalismDetection::PageParser.new
      @feature_calculator = Wikipedia::VandalismDetection::FeatureCalculator.new
    end

    # context written key: 'page id, page title'
    # context written values: 'old revision id, new revison id' of reverted edits
    # (or empty string if no reverted edits has been found)
    def map(key, value, context)
      page_id = Saxerator.parser(value.to_s).for_tag(:id).within(:page).first
      return unless Conditions::PageIds.available?(page_id)

      page = @parser.parse(value.to_s)
      @key.set [page.id, page.title, page.revisions.count].join(',')

      reverted_sha1s = {}
      v = Wikipedia::VandalismDetection::Instances::VANDALISM_SHORT
      r = Wikipedia::VandalismDetection::Instances::REGULAR_SHORT

      reverted_edits = page.reverted_edits

      # write 'simple vandalism' edits
      if reverted_edits.count > 0
        Parallel.each(reverted_edits) do |edit|
          features = @feature_calculator.calculate_features_for(edit)
          reverted_sha1s[:"#{edit.old_revision.sha1}-#{edit.new_revision.sha1}"] = :v

          edit_info = [edit.old_revision.id, edit.new_revision.id, v, *features]

          @value.set edit_info.join(',')
          context.write(@key, @value)
        end
      end

      edits = page.edits

      # write 'regular' edits
      Parallel.each(edits) do |edit|
        sha1_hash = :"#{edit.old_revision.sha1}-#{edit.new_revision.sha1}"

        unless reverted_sha1s.include?(sha1_hash)
          features = @feature_calculator.calculate_features_for(edit)

          edit_info = [edit.old_revision.id, edit.new_revision.id, r, *features]

          @value.set edit_info.join(',')
          context.write(@key, @value)
        end
      end
    end
  end
end