# encoding: utf-8

require 'singleton'
require 'csv'

module Conditions

  class PageIds
    include Singleton

    def initialize
      file = File.expand_path("../page_ids/pages_with_most_revisions.csv", __FILE__)
      @page_ids = CSV.parse(File.read(file), headers: true)
    end

    def self.available?(id)
      self.instance.available?(id)
    end

    def available?(id)
      !!@page_ids.find { |row| row['page_id'].to_s == id.to_s }
    end
  end

end