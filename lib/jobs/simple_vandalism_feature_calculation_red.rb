require 'jobs/base/mapper'
require 'jobs/simple_vandalism/feature_calculation/reducer'

Rubydoop.configure do |input_path, output_path|
  job 'WVD - Simple vandalism feature calculation - reduce' do
    input input_path
    output output_path

    mapper Base::Mapper
    reducer SimpleVandalism::FeatureCalculation::Reducer

    output_key Hadoop::Io::Text
    output_value Hadoop::Io::Text
  end
end