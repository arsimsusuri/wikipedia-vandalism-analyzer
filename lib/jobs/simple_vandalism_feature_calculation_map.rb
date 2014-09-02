require 'hadoop/mapreduce/lib/input/xml_input_format'
require 'jobs/simple_vandalism/feature_calculation/mapper'
require 'jobs/simple_vandalism/feature_calculation/reducer'
require 'wikipedia/vandalism_detection/revision'

Rubydoop.configure do |input_path, output_path|
  job 'WVD - Simple vandalism feature calculation - map' do
    input input_path, format: "Xml"
    output output_path

    mapper SimpleVandalism::FeatureCalculation::Mapper
    raw { |job| job.set_num_reduce_tasks 0 } #reducer SimpleVandalism::FeatureCalculation::Reducer #

    start_tag = Wikipedia::VandalismDetection::Revision::START_TAG
    end_tag = Wikipedia::VandalismDetection::Revision::END_TAG

    set Hadoop::Mapreduce::Lib::Input::XmlInputFormat::START_TAG_KEY, start_tag
    set Hadoop::Mapreduce::Lib::Input::XmlInputFormat::END_TAG_KEY, end_tag

    output_key Hadoop::Io::Text
    output_value Hadoop::Io::Text
  end
end