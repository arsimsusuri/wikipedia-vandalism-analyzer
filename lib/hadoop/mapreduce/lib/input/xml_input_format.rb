require 'wikipedia/vandalism_analyzer/exceptions'

module Hadoop
  module Mapreduce
    module Lib
      module Input
        require 'java'

        begin
          #hadoop_path = ENV['PATH'].split(':').select { |path| path =~ /hadoop\-*/ }.first.gsub(/\/bin*/, '')
          hadoop_path = "/opt/hadoop-1.2.1"
          hadoop_core_jar = Dir[File.join(hadoop_path, "hadoop-core-*.jar")].first
          logging_jar = Dir[File.join(hadoop_path, 'lib', "commons-logging-*.jar")].first

          require hadoop_core_jar
          require logging_jar
        rescue
          message = %Q{
            Hadoop could not be found.
            Ensure that the $PATH environment variable includes your hadoop installation directory.
          }

          raise Wikipedia::VandalismAnalyzer::HadoopNotFoundError, message
        end

        require 'java/cloud9-wikipedia.jar'
        java_import 'edu.umd.cloud9.collection.XMLInputFormat'

        # This class wrapps the edu.umd.cloud9.collection.XMLInputFormat Java class and provides an additional
        # InputFormat to use in Hadoop jobs. XmlInputFormat allows to split XML files by a defined tag name.
        class XmlInputFormat < XMLInputFormat; end
      end
    end
  end
end