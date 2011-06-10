require "spec_helper"

module Harpy
  module Spec
    class Company
      include Harpy::Resource
    end
  end
end

describe Harpy::Resource do
  describe "client" do
    it "uses Harpy::Client as client" do
      Harpy::Resource.client.should be_kind_of Harpy::Client
    end
    it "allows setting a custom client" do
      client = mock("MyClient")
      Harpy::Resource.client = client
      Harpy::Resource.client.should == client
      Harpy::Resource.client = nil
    end
  end
  describe "entry_point" do
    it "defaults to nil" do
      Harpy::Resource.entry_point.should be_nil
    end
    it "allows setting a custom entry_point" do
      entry_point = mock("MyEntryPoint")
      Harpy::Resource.entry_point = entry_point
      Harpy::Resource.entry_point.should == entry_point
      Harpy::Resource.entry_point = nil
    end
  end
  describe ".from_url(hash)" do
    let(:company_url) { "http://localhost/company/1" }
    let(:json_response) { %Q|{"name": "Harpy ltd", "link": [{"rel": "self", "href": "#{company_url}"}]}| }
    let(:success_response) { Typhoeus::Response.new :code => 200, :body => json_response}
    it "queries multiple resources in parallel and return instances" do
      Typhoeus::Hydra.hydra.stub(:get, company_url).and_return success_response
      responses = Harpy::Resource.from_url({ Harpy::Spec::Company => [company_url] })
      responses.should have(1).keys
      responses[Harpy::Spec::Company].should have(1).item
      responses[Harpy::Spec::Company].first.name.should == "Harpy ltd"
    end
  end
end

describe Harpy::Spec::Company do
end