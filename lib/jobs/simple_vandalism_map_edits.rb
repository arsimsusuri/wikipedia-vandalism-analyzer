require 'hadoop/mapreduce/lib/input/xml_input_format'
require 'jobs/simple_vandalism/mapper'
require 'wikipedia/vandalism_detection/page'

Rubydoop.configure do |input_path, output_path|
  job 'WikipediaVandalism - Simple Vandalism Edits (Map)' do
    input input_path, format: "Xml"
    output output_path

    mapper SimpleVandalism::Mapper
    raw { |job| job.set_num_reduce_tasks 0 }

    start_tag = Wikipedia::VandalismDetection::Page::START_TAG
    end_tag = Wikipedia::VandalismDetection::Page::END_TAG

    set Hadoop::Mapreduce::Lib::Input::XmlInputFormat::START_TAG_KEY, start_tag
    set Hadoop::Mapreduce::Lib::Input::XmlInputFormat::END_TAG_KEY, end_tag

    output_key Hadoop::Io::Text
    output_value Hadoop::Io::Text
  end
end