require 'hadoop/mapreduce/lib/input/xml_input_format'
require 'jobs/simple_vandalism/reducer'
require 'jobs/base/mapper'

Rubydoop.configure do |input_path, output_path|
  job 'WikipediaVandalism - Simple Vandalism Count per Page (Red)' do
    input input_path
    output output_path

    mapper Base::Mapper
    reducer SimpleVandalism::Reducer

    map_output_value Hadoop::Io::Text
    output_key Hadoop::Io::Text
    output_value Hadoop::Io::IntWritable
  end
end