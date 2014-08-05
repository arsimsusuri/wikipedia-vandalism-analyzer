require 'spec_helper'

describe Hadoop::Mapreduce::Lib::Input::XmlInputFormat do

  it "can be required without errors" do
    expect { require 'hadoop/mapreduce/lib/input/xml_input_format' }.not_to raise_error
  end

  it "is an XMLInputformat from the Cloud9 lib" do
    class_type = Java::EduUmdCloud9Collection::XMLInputFormat
    expect(Hadoop::Mapreduce::Lib::Input::XmlInputFormat.ancestors[1]).to be class_type
  end
end