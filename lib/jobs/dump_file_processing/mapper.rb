require_relative '../../acquisition/page_parser'

module DumpFileProcessing
  class Mapper

    def initialize
      @key = Hadoop::Io::Text.new
      @value = Hadoop::Io::Text.new
    end

    def map(key, value, context)
      parser = Wikipedia::PageParser.new
      page = parser.parse value.to_s

      unless page.nil?
        @key.set page.id

        page.edits.each do |edit|
          @value.set "#{edit.old_revision.id}\t#{edit.new_revision.id}"
          context.write @key, @value
        end
      end
    end
  end
end