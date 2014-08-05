require 'hadoop/mapreduce/lib/input/xml_input_format'
require 'jobs/classification/mapper'
require 'ruby-band'

Rubydoop.configure do |input_path, output_path|
  job 'WikipediaVandalism - Classification' do
    input input_path
    output File.join(output_path, Classification::OUTPUT_PATH)

    mapper Classification::Mapper
    raw { |job| job.set_num_reduce_tasks 0 }

    output_key Hadoop::Io::Text
    output_value Hadoop::Io::Text
  end
end