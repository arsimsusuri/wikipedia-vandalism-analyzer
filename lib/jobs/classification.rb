require 'hadoop/mapreduce/lib/input/xml_input_format'
require 'jobs/classification/mapper'
require 'wikipedia/vandalism_detection'

Rubydoop.configure do |input_path, output_path|
  job 'wikipedia_vandalism_classification' do
    input input_path#, format: Wikipedia::XmlInputFormat
    output output_path#, format: "Text"

    mapper Classification::Mapper
    raw { |job| job.set_num_reduce_tasks 0 }

    output_key Hadoop::Io::Text
    output_value Hadoop::Io::Text

    $classifier = Wikipedia::VandalismDetection::Classifier.new
  end
end