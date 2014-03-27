module Classification
  class Mapper

    def initialize
      @key = Hadoop::Io::Text.new
      @value = Hadoop::Io::Text.new
    end

    def map(key, value, context)
      data = value.to_s.split("\t")
      features = data[1].split(',').map(&:to_f)
      consensus = $classifier.classify features

      @key.set data[0]
      @value.set consensus.to_s

      context.write @key, @value
    end

  end
end