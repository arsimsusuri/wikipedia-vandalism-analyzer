module Base

  class Mapper

    def initialize
      @key = Hadoop::Io::Text.new
      @value = Hadoop::Io::Text.new
    end

    # Just writes the context from text file input line as key value pair (split up by tabulator).
    def map(key, value, context)
      line = value.to_s.split("\t")
      @key.set line[0]
      @value.set line[1]

      context.write(@key, @value)
    end
  end
end
