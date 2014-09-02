#!/usr/bin/env jruby

require 'rubygems'
require 'nokogiri'
require 'open-uri'

dump_date = ARGV[0] || raise(ArgumentError, 'You have to specify the dump date as first parameter, e.g. "20140614".')
file_format = ARGV[1] || raise(ArgumentError, 'You have to specify the file format (7z, bz2) as second parameter.')
uri = "http://dumps.wikimedia.org/enwiki/#{dump_date}/"

page = Nokogiri::HTML(open(uri))

list = page.xpath("//li[@class='file']/a").select {|a| a.text =~ /enwiki-.+-pages-meta-history\d+.xml-.+\.#{file_format}/ }.map {|a| uri + a.text }

file_sizes = page.xpath("//li[@class='file']").select {|li| li.children.select(&:element?).first.text =~ /enwiki-.+-pages-meta-history\d+.xml-.+\.#{file_format}/ }

total_size = file_sizes.reduce(0) do |sum, item| 
  size = item.xpath('text()').text
  size = size =~ /GB/ ? size.to_f * 1024.0 : size.to_f 

  sum + size.to_f
end

puts "Total size: #{total_size / 1024.0} GB"

File.open('urls.txt', 'w') do |f|
  f.puts list
end

# to download files run
# $ wget --input-file=urls.txt


