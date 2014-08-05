module SimpleVandalism

  class Reducer

    def initialize
      @key = Hadoop::Io::Text.new
      @value = Hadoop::Io::Text.new
    end

    def reduce(key, values, context)
      edits_count = values.reduce(0) { |sum, edit_info|  sum + 1 unless edit_info.to_s.empty? }

      @key.set key
      @value.set edits_count.to_s

      context.write(@key, @value)
    end
  end
end