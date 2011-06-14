require "spec_helper"

describe Harpy::Resource do
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

module Harpy
  module Spec
    class Company
      include Harpy::Resource
    end
  end
end
describe Harpy::Spec::Company do
  after{ Harpy.reset }
  describe ".from_url(url)" do
    context "called with only one url" do
      let(:url){ "http://localhost/company/1" }
      it "returns a properly filled-in instance of Harpy::Spec::Company on success" do
        response = Typhoeus::Response.new :code => 200, :body => <<-eos
          {
            "name": "Harpy Ltd",
            "link": [
              {"rel": "self", "href": "#{url}"}
            ]
          }
        eos
        Harpy.client.should_receive(:get).with(url).and_return response
        result = Harpy::Spec::Company.from_url url
        result.should be_kind_of Harpy::Spec::Company
        result.name.should == "Harpy Ltd"
        result.link("self").should == url
      end
      it "returns nil when not found" do
        response = Typhoeus::Response.new :code => 404
        Harpy.client.should_receive(:get).with(url).and_return response
        Harpy::Spec::Company.from_url(url).should be_nil
      end
      it "delegates response code != 200 or 404 to client" do
        response = Typhoeus::Response.new :code => 500
        Harpy.client.should_receive(:get).with(url).and_return response
        Harpy.client.should_receive(:invalid_code).with response
        Harpy::Spec::Company.from_url(url)
      end
    end
  end
  describe ".from_id(id)" do
    context "when entry point is configured" do
      it "raises Harpy::EntryPointRequired" do
        lambda{
          Harpy::Spec::Company.from_id(1)
        }.should raise_error Harpy::EntryPointRequired
      end
    end
    context "when entry point is set but urn has not been overriden" do
      it "raises NotImplementedError" do
        Harpy.entry_point_url = "http://localhost"
        lambda{
          Harpy::Spec::Company.from_id(1)
        }.should raise_error NotImplementedError
      end
    end
    context "when entry point is set and urn has been overriden" do
      let(:urn) { "urn:harpy:company:1" }
      let(:url) { "http://localhost/company/1" }
      it "asks Harpy.entry_point to convert urn to url then call .from_url" do
        # 1 -> urn:harpy:company:1
        Harpy::Spec::Company.should_receive(:urn).with(1).and_return urn
        
        # urn:harpy:company:1 -> http://localhost/company/1
        Harpy.entry_point = mock
        Harpy.entry_point.should_receive(:urn).with(urn).and_return url
        
        # http://localhost/company/1 -> Harpy::Spec::Company instance
        Harpy::Spec::Company.should_receive(:from_url).with(url).and_return(expected = mock)
        Harpy::Spec::Company.from_id(1).should be expected
      end
      it "returns nil if urn is not found" do
        # 1 -> urn:harpy:company:1
        Harpy::Spec::Company.should_receive(:urn).with(1).and_return urn
        
        # urn:harpy:company:1 -> nil
        Harpy.entry_point = mock
        Harpy.entry_point.should_receive(:urn).with(urn)
        
        Harpy::Spec::Company.from_id(1).should be_nil
      end
    end
  end
  describe ".urn(id)" do
    it "raises NotImplementedError" do
      lambda{
        Harpy::Spec::Company.urn(1)
      }.should raise_error NotImplementedError
    end
  end
end