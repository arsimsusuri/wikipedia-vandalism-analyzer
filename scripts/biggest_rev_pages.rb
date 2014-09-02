require 'rubygems'
require 'nokogiri'
require 'open-uri'
require 'parallel'
require 'csv'
require 'active_support/inflector'

path = "http://en.wikipedia.org/wiki/Wikipedia:Database_reports/Pages_with_the_most_revisions"
api_url = "http://en.wikipedia.org/w/api.php?format=xml&action=query&titles="
page = Nokogiri::HTML(open(path))

articles = page.xpath("//tr").select { |row| row.children.children[1].text == '0' } # ID = 0

file = CSV.open('pages_with_most_revisions.csv', 'w') do |csv|
  csv << ['page_id', 'page_name', 'revisions']

  # write to csv file
  Parallel.each(articles) do |article|
    tds = article.children.children
    article_name = tds[2].text
    revisions_count = tds[3].text

    uri = URI::encode("#{api_url}#{article_name}&redirects")
    content = URI.parse(uri).read
    article_id = Nokogiri::XML(content).xpath("//page/@pageid").first.text

    item = [article_id, ActiveSupport::Inflector.transliterate(article_name), revisions_count]
    puts "#{item.join(',')}"

    csv << item
  end
end
