require "spec_helper"

describe Harpy::EntryPoint do
  let(:url) { "http://localhost" }
  subject { Harpy::EntryPoint.new url}

  it "should store url" do
    subject.url.should == url
  end

  describe "#resource_url(resource_type)" do
    let(:company_url) { "#{url}/company"}
    let(:json_response) { %Q|{"link": [{"rel": "company", "href": "#{company_url}"}]}| }
    let(:success_response) {  Typhoeus::Response.new :code => 200, :body => json_response }
    let(:error_response) {  Typhoeus::Response.new :code => 500 }
    it "gets entry point from url using client" do
      Harpy.client.should_receive(:get).with(url).and_return success_response
      subject.resource_url "user"
    end
    it "return nil if no link for resource_type" do
      Harpy.client.should_receive(:get).with(url).and_return success_response
      subject.resource_url("user").should be_nil
    end
    it "return url for existing resource_type" do
      Harpy.client.should_receive(:get).with(url).and_return success_response
      subject.resource_url("company_url").should be_nil
    end
    it "delegates response code != 200 to client" do
      Harpy.client.should_receive(:get).with(url).and_return error_response
      Harpy.client.should_receive(:invalid_code).with error_response
      subject.resource_url("company_url")
    end
  end
  
  describe "#urn(urn)" do
    let(:urn) { "urn:harpy:company:1" }
    let(:company_url) { "#{url}/company/1"}
    let(:success_response) {  Typhoeus::Response.new :code => 301, :headers => "Location: #{company_url}" }
    let(:error_response) {  Typhoeus::Response.new :code => 500 }
    let(:not_found_response) {  Typhoeus::Response.new :code => 404 }
    it "query remote for this urn using client" do
      Harpy.client.should_receive(:get).with("#{url}/#{urn}").and_return success_response
      subject.urn(urn).should == company_url
    end
    it "return nil if not found" do
      Harpy.client.should_receive(:get).with("#{url}/#{urn}").and_return not_found_response
      subject.urn(urn).should be_nil
    end
    it "delegates response code != 301 or 404 to client" do
      Harpy.client.should_receive(:get).with("#{url}/#{urn}").and_return error_response
      Harpy.client.should_receive(:invalid_code).with error_response
      subject.urn(urn)
    end
  end
  
end