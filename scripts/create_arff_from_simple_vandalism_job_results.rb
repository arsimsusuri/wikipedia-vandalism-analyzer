#!/usr/bin/env jruby

# This script creates arff files based on a given file consisting of jobs/simple_vandalism_map_edits results.
#
# @author: Paul Götze <paul.christoph.goetze@gmail.com>, August 2014
#
# @exmaple
#   ruby create_arff_from_simple_vandalism_job_results.rb /absolute/path/to/the/result/file/part-m-00000
#
# instead of 'ruby' you can of course also use 'jruby'

require 'fileutils'
require 'wikipedia/vandalism_detection'

class ArffCreator

  attr_reader :file, :vandalism_count, :regular_count

  REGULAR = 'regular'
  VANDALISM = 'vandalism'

  # takes a File pointer as param
  def initialize(file)
    @file = file
    @vandalism_count = 0
    @regular_count = 0
  end

  def write_header(data)
    relation_name = data[0]
    features_count = data[1].split(',').count - 3

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
    class_value_regular = (class_value == 'R')
    class_name = class_value_regular ? REGULAR : VANDALISM

    @file.puts [*features, class_name].join(',')

    if class_value_regular
      @regular_count += 1
    else
      @vandalism_count += 1
    end
  end

  def info
    [@page_info, [@vandalism_count, @regular_count].join(',')].join("\t")
  end
end


src_dir = ARGV[0] || raise(ArgumentError, "Please define a file to convert as first parameter:\nruby create_arff_from_simple_vandalism_job_results.rb /src-file/part-m-00000")
dst_dir = ARGV[1] || raise(ArgumentError, "Please define the dest dir as second parameter:\nruby create_arff_from_simple_vandalism_job_results.rb /src-file/part-m-00000 /dest-dir/")

FileUtils.mkdir_p(dst_dir)

@info_file = File.open(File.join(dst_dir, 'article-info.txt'), 'w')
src_files = Dir[File.join(src_dir, '*')].select { |f| f =~ /(part-.-\d+$)/}

@creator = nil
@skipped_file = false

@written_headers = {}

src_files.each_with_index do |src_file_path, file_index|
  begin
    new_page = true
    previous_page_id = nil

    lines = File.read(src_file_path).lines

    lines.each_with_index do |line, index|
      data = line.split("\t")
      current_page_id = data[0]

      new_page = !(previous_page_id && current_page_id == previous_page_id)
      print "\r processed #{ ((100.0 * (file_index + 1)) / src_files.count).round(1) }%" if new_page

      if (@creator && new_page && !@skipped_file) || index == lines.count - 1
        @info_file.puts @creator.info
      end

      title = current_page_id

      if title !~ /(talk:|category:)/i # only articles
        if new_page
          arff = File.open(File.join(dst_dir, "page-#{current_page_id}.arff"), 'a')
          @creator = ArffCreator.new(arff)

          unless @written_headers[current_page_id]
            @creator.write_header(data)
            @written_headers[current_page_id] = true
          end
        end

        @creator.write_data(data[1])
        @skipped_file = false
      else
        @skipped_file = true
      end

      previous_page_id = current_page_id
    end
  rescue => e
    puts "Error: file '#{File.basename(src_file_path)}' cannot be converted.\n#{e}"
    next
  end
end

@info_file.close