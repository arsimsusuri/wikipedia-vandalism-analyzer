module Wikipedia
  module VandalismAnalyzer

    # @abstract Exceptions raised by Wikipedia::VandalismAnalyzer inherit from this Error
    class Error < StandardError; end

    # Exception is raised when the $PATH env variable does not include the hadoop install path
    class HadoopNotFoundError < Error; end
  end
end