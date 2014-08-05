require 'spec_helper'

describe Conditions::PageIds do

  it "is a singleton class" do
    expect {Conditions::PageIds.instance }.to_not raise_error
  end

  describe "#instance.available?" do
    it "returns true if id is in csv file" do
      expect(Conditions::PageIds.instance.available?('3414021')).to be true
    end

    it "returns false if id is not in csv file" do
      expect(Conditions::PageIds.instance.available?('0815-Not-Available')).to be false
    end
  end

  describe "#available?" do
    it "returns true if id is in csv file" do
      expect(Conditions::PageIds.available?('3414021')).to be true
    end

    it "returns false if id is not in csv file" do
      expect(Conditions::PageIds.available?('0815-Not-Available')).to be false
    end
  end
end