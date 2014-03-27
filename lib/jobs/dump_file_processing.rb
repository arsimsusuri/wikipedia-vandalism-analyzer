require_relative 'dump_file_processing/mapper'
require_relative '../../hadoop/xml_input_format'
require_relative '../acquisition/page'

Rubydoop.configure do |input_path, output_path|
  job 'dump_file_processing' do

    input input_path, format: Wikipedia::XmlInputFormat
    output output_path, format: "Text"

    mapper DumpFileProcessing::Mapper
    raw { |job| job.set_num_reduce_tasks 0 }

    start_tag = Wikipedia::Page::START_TAG
    end_tag = Wikipedia::Page::END_TAG

    set Wikipedia::XmlInputFormat::START_TAG_KEY, start_tag
    set Wikipedia::XmlInputFormat::END_TAG_KEY, end_tag

    output_key Hadoop::Io::Text
    output_value Hadoop::Io::Text
  end
end