require 'wikipedia/vandalism_detection'
require 'jobs/conditions/page_ids'
require 'saxerator'

module SimpleVandalism

  class Mapper

    def initialize
      @key = Hadoop::Io::Text.new
      @value = Hadoop::Io::Text.new
      @parser = Wikipedia::VandalismDetection::PageParser.new
    end

    # context written key: 'page id, page title, revisions count'
    # context written values: 'old revision id, new revison id, simple vandalism class' of reverted edits
    # (or empty string if no reverted edits has been found)
    def map(key, value, context)
      value = value.to_s
      page_id = Saxerator.parser(value).for_tag(:id).within(:page).first
      return unless Conditions::PageIds.available?(page_id)

      page = @parser.parse(value)
      value = nil # reset value

      @key.set [page.id, page.title, page.revisions.count].join(',')

      reverted_sha1s = {}
      v = Wikipedia::VandalismDetection::Instances::VANDALISM_SHORT
      r = Wikipedia::VandalismDetection::Instances::REGULAR_SHORT

      reverted_edits = page.reverted_edits

      # write 'simple vandalism' edits
      if reverted_edits.count > 0
        reverted_edits.each do |edit|
          reverted_sha1s["#{edit.old_revision.sha1}-#{edit.new_revision.sha1}"] = :v

          edit_info = [edit.old_revision.id, edit.new_revision.id, v]

          @value.set edit_info.join(',')
          context.write(@key, @value)
        end
      end

      reverted_edits = nil # reset reverted_edits variable
      edits = page.edits

      # write 'regular' edits
      edits.each do |edit|
        sha1_hash = "#{edit.old_revision.sha1}-#{edit.new_revision.sha1}"

        unless reverted_sha1s.has_key?(sha1_hash)
          edit_info = [edit.old_revision.id, edit.new_revision.id, r]

          @value.set edit_info.join(',')
          context.write(@key, @value)
        end
      end
    end
  end
end