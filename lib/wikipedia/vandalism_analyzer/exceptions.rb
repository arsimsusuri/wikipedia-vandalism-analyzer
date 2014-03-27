module Wikipedia
  module VandalismAnalyzer

    # @abstract Exceptions raised by Wikipedia::VandalismAnalyzer inherit from this Error
    class Error < StandardError; end

    # Exception is raised when the $HADOOP_INSTALL system path is not set
    class HadoopNotFoundError < Error; end
  end
end