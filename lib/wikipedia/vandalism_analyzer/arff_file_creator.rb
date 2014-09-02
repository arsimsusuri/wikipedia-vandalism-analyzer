require 'wikipedia/vandalism_detection'

class ArffCreator

  attr_reader :file, :vandalism_count, :regular_count
  attr_accessor :page_info

  REGULAR = Wikipedia::VandalismDetection::Instances::REGULAR
  VANDALISM = Wikipedia::VandalismDetection::Instances::VANDALISM

  # takes a File pointer as param
  def initialize(file)
    @file = file
    @vandalism_count = 0
    @regular_count = 0
  end

  def write_header(data)
    relation_name = data[0]

    @page_info = relation_name

    @file.puts "@relation '#{relation_name}'"
    @file.puts "\n"

    features = Wikipedia::VandalismDetection.configuration.features

    features.each do |feature|
      name = feature.gsub(/[\-\s]/, '_')
      @file.puts "@attribute #{name} numeric"
    end

    @file.puts "@attribute class {#{REGULAR},#{VANDALISM}}"
    @file.puts "\n@data"
  end

  def write_data(line)
    data = line.strip.split(',')

    features = data[3..-1]
    class_value = data[2]
    class_value_regular = class_value == 'R'
    class_name = class_value_regular ? REGULAR : VANDALISM

    @file.puts [*features, class_name].join(',')

    if class_value_regular
      @regular_count += 1
    else
      @vandalism_count += 1
    end
  end

  def info
    [@page_info, @vandalism_count, @regular_count].join(',')
  end
end