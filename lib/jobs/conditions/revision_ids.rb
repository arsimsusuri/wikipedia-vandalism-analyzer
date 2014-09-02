# encoding: utf-8

require 'singleton'
require 'csv'

module Conditions

  class RevisionIds
    include Singleton

    def initialize
      file = File.expand_path("../revision_ids/revisions.csv", __FILE__)
      @revision_ids = CSV.parse(File.read(file), headers: true)
    end

    def self.available?(id)
      self.instance.available?(id)
    end

    def self.data_for_revision(id)
      self.instance.data_for_revision(id)
    end

    def available?(id)
      !!data_for_revision(id)
    end

    def data_for_revision(id)
      data = @revision_ids.find { |row| row['revision_id'].to_s == id.to_s }
      data.to_hash if data
    end



  end

end