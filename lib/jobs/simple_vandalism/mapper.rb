require 'wikipedia/vandalism_detection'
require 'jobs/conditions/page_ids'
require 'saxerator'
require 'benchmark'

module SimpleVandalism

  class Mapper

    def initialize
      @key = Hadoop::Io::Text.new
      @value = Hadoop::Io::Text.new
      @parser = Wikipedia::VandalismDetection::PageParser.new
    end

    # context written key: 'page id, page title'
    # context written values: 'old revision id, new revison id' of reverted edits
    # (or empty string if no reverted edits has been found)
    def map(key, value, context)
      page_id = Saxerator.parser(value.to_s).for_tag(:id).within(:page).first
      return unless Conditions::PageIds.available?(page_id)

      page = @parser.parse(value.to_s)

      edits = page.reverted_edits
      @key.set [page.id, page.title, page.revisions.count].join(',')

      if edits.count > 0
        edits.each do |edit|
          edit_info = [edit.old_revision.id, edit.new_revision.id]

          @value.set edit_info.join(',')
          context.write(@key, @value)
        end
      else
        @value.set ""
        context.write(@key, @value)
      end
    end
  end
end