require 'hadoop/mapreduce/lib/input/xml_input_format'
require 'jobs/feature_calculation/mapper'
require 'jobs/classification/mapper'
require 'ruby-band'

Rubydoop.configure do |input_path, output_path|
  job 'WikipediaVandalism - Feature Calculation' do
    input input_path, format: "Xml"
    output File.join(output_path, FeatureCalculation::OUTPUT_PATH)

    mapper FeatureCalculation::Mapper
    raw { |job| job.set_num_reduce_tasks 0 }

    start_tag = Wikipedia::VandalismDetection::Page::START_TAG
    end_tag = Wikipedia::VandalismDetection::Page::END_TAG

    set Hadoop::Mapreduce::Lib::Input::XmlInputFormat::START_TAG_KEY, start_tag
    set Hadoop::Mapreduce::Lib::Input::XmlInputFormat::END_TAG_KEY, end_tag

    output_key Hadoop::Io::Text
    output_value Hadoop::Io::Text
  end

  job 'WikipediaVandalism - Classification' do
    input File.join(output_path, FeatureCalculation::OUTPUT_PATH)
    output File.join(output_path, Classification::OUTPUT_PATH)

    mapper Classification::Mapper
    raw { |job| job.set_num_reduce_tasks 0 }

    output_key Hadoop::Io::Text
    output_value Hadoop::Io::Text
  end
end