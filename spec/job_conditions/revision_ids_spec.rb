require 'spec_helper'

describe Conditions::RevisionIds do

  it "is a singleton class" do
    expect {Conditions::RevisionIds.instance }.to_not raise_error
  end

  before do
    content = "page_id,revision_id,simple_vandalism\n1,2,R\n1,4,V\n2,5,R"
    csv = CSV.parse(content, headers: true)
    Conditions::RevisionIds.instance.instance_variable_set(:@revision_ids, csv)
  end

  describe "#instance.available?" do
    it "returns true if id is in txt file" do
      expect(Conditions::RevisionIds.instance.available?('2')).to be true
    end

    it "returns false if id is not in csv file" do
      expect(Conditions::RevisionIds.instance.available?('0815-Not-Available')).to be false
    end
  end

  describe "#available?" do
    it "returns true if id is in csv file" do
      expect(Conditions::RevisionIds.available?('2')).to be true
    end

    it "returns false if id is not in csv file" do
      expect(Conditions::RevisionIds.available?('0815-Not-Available')).to be false
    end
  end

  describe "#instance.data_for_revision" do
    it "returns the page info if available" do
      info = { 'page_id' => '1', 'revision_id' => '2', 'simple_vandalism' => 'R' }
      expect(Conditions::RevisionIds.instance.data_for_revision('2')).to eq info
    end
  end

  describe "#data_for_revision" do
    it "returns nil if not available" do
      expect(Conditions::RevisionIds.data_for_revision('0815-Not-Available')).to be_falsey
    end
  end
end