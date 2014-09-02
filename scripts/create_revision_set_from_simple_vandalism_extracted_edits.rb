#!/usr/bin/env jruby

# This script writes the revision ids resulting from jobs/simple_vandalism_extract_edits into a revisions.txt file.
#
# @author: Paul Götze <paul.christoph.goetze@gmail.com>, August 2014
#
# @exmaple
#   ruby create_revision_set_from_simple_vandalism_extracted_edits.rb /absolute/path/to/the/result/file/part-m-00000 /dest/dir/
#
# instead of 'ruby' you can of course also use 'jruby'

require 'fileutils'

src_dir = ARGV[0] || raise(ArgumentError, "Please define a file to process as first parameter (e.g. /src-file/part-m-00000)")
dst_dir = ARGV[1] || raise(ArgumentError, "Please define the dest dir as second parameter: e.g. /src-file/dest-dir/")

allowed_page_ids = ARGV[2] ? ARGV[2].split(',') : nil

FileUtils.mkdir_p(dst_dir)

@file = File.open(File.join(dst_dir, 'revisions.csv'), 'w')
@file.puts ['page_id', 'revision_id', 'simple_vandalism'].join(',')

src_files = Dir[File.join(src_dir, '*')].select { |f| f =~ /(part-.-\d+$)/}

src_files.each_with_index do |src_file_path, file_index|
  begin
    lines = File.read(src_file_path).lines

    lines.each do |line|
      data = line.split("\t")
      page_id = data[0].split(',').first

      next if allowed_page_ids && !allowed_page_ids.include?(page_id)

      values = data[1].split(',')
      revision_id = values[1]
      simple_vandalism = values[2]

      @file.puts [page_id, revision_id, simple_vandalism].join(',')

      print "\r processed #{ ((100.0 * (file_index + 1)) / src_files.count).round(1) }%"
    end
  rescue => e
    puts "Error: file '#{File.basename(src_file_path)}' cannot be processed.\n#{e}"
    next
  end
end

@file.close