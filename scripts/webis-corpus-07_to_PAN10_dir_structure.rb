require 'nokogiri'
require 'fileutils'
require 'open-uri'
require 'csv'

# Parses the xml string to a Nokogiri document
def document_for(revision_id)
  url = "http://en.wikipedia.org/w/api.php?action=query&format=xml&prop=revisions&rvprop=ids%7Cuser%7Ccomment%7Ctimestamp%7Ccontent&revids="

  full_url = "#{url}#{revision_id}"

  xml = open(full_url).read
  Nokogiri::XML(xml)
end

# Returns the revisions data from the given Nokogiri document
def edit_data_from(document, old_revision_id, new_revision_id)
  editor = document.xpath('//rev/@user')
  diffurl = "http://en.wikipedia.org/w/index.php?diff=#{new_revision_id}&oldid=#{old_revision_id}"
  edittime = document.xpath('//rev/@timestamp')
  editcomment = document.xpath('//rev/@comment')
  articleid = document.xpath('//page/@pageid')
  articletitle = document.xpath('//page/@title')

  [editor, old_revision_id, new_revision_id, diffurl, edittime, editcomment, articleid, articletitle]
end

# Creates the edits csv file from given edits data
def create_edits_csv(data)
  print "\ncreate edits csv..."
  path = File.expand_path("../../data/corpus-07/edits.csv", __FILE__)
  header =  ["editid", "editor", "oldrevisionid", "newrevisionid", "diffurl",
      "edittime", "editcomment", "articleid", "articletitle"]

  CSV.open(path, 'w', :write_headers => true, :headers => header) do |csv|
    data.each_with_index do |row, index|
      csv << [index + 1, *row]
    end
  end

  print "done\n"
end

# Creates the annotations csv file from the given annotations data
def create_annotations_csv(data)
  print "\ncreate annotations csv..."
  path = File.expand_path("../../data/corpus-07/annotations.csv", __FILE__)
  header = ["editid", "class"]

  CSV.open(path, 'w', :write_headers => true, :headers => header) do |csv|
    data.each_with_index do |row, index|
      csv << [index + 1, *row]
    end
  end

  print "done\n"
end

corpus_dir = File.expand_path("../../data/corpus-07", __FILE__)
revisions_dir = "#{corpus_dir}/revisions"
@sub_revisions_dir = "#{revisions_dir}/part-1"
xml_path = File.expand_path('../../data/corpus-webis-wvc-07/wwvc-11-07.xml', __FILE__)
log_file_path = File.expand_path('../../data/corpus-07/build.log', __FILE__)

# Creates an <id>.txt file holding the content for revision id
def create_content_file(id, content)
  File.open("#{@sub_revisions_dir}/#{id}.txt", 'w') do |f|
    f.puts content
  end
end

FileUtils.mkdir corpus_dir unless Dir.exists?(corpus_dir)
FileUtils.mkdir revisions_dir unless Dir.exists?(revisions_dir)
FileUtils.mkdir @sub_revisions_dir unless Dir.exists?(@sub_revisions_dir)

document = Nokogiri::XML(File.open(xml_path))
document.remove_namespaces!

edits = document.xpath('//edit')
edits_count = edits.count
puts "total edits: #{edits_count}"

vandalism_count = 0
regular_count = 0
edits_data = Array.new
annotations_data = Array.new

log_file = File.open(log_file_path, 'w')

edits.each_with_index do |edit, index|
  new_revision_id = edit.xpath('newRevisionID').inner_text
  old_revision_id = edit.xpath('oldRevisionID').inner_text
  vandalism = !edit.xpath('vandalism').empty? ? "regular" : "vandalism"

  if vandalism == "vandalism"
    vandalism_count += 1
  else
    regular_count += 1
  end

  print "\rreading edit #{index + 1}/#{edits_count} - with old: #{old_revision_id}, new: #{new_revision_id}..."

  new_doc = document_for new_revision_id
  old_doc = document_for old_revision_id

  if new_doc.xpath('//revisions').count == 0
    log_file.puts "Edit not available: new revision missing #{new_revision_id} - Discarded!"
    next
  elsif new_doc.xpath('//rev/@parentid').inner_text.to_i ==  0
    log_file.puts "No edit: Article created revision - old revision missing #{old_revision_id} (new revision #{new_revision_id}) - Discarded!\n"
    next
  elsif old_doc.xpath('//revisions').count == 0
    log_file.puts "Edit not available: old revision missing #{old_revision_id} (new revision #{new_revision_id}) - Discarded!\n"
    next
  else
    old_content = old_doc.xpath('//rev').inner_text
    new_content = new_doc.xpath('//rev').inner_text

    create_content_file(old_revision_id, old_content)
    create_content_file(new_revision_id, new_content)

    edits_data << edit_data_from(new_doc, old_revision_id, new_revision_id)
    annotations_data << vandalism
    #break if index > 4
  end
end

create_edits_csv(edits_data)
create_annotations_csv(annotations_data)

log_file.close

puts "counts: vandalism #{vandalism_count} | regular #{regular_count}"

