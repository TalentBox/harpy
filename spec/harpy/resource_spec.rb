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
      attr_accessor :tax_id
    end
    class User
      include Harpy::Resource
      validates_presence_of :firstname
      before_validation :check_lastname
      before_save :callback_before_save
      before_create :callback_before_create
      before_update :callback_before_update
      before_destroy :callback_before_destroy
      attr_reader :callbacks
      def initialize(*args)
        @callbacks = []
        super
      end
      def check_lastname
        !!lastname
      end
      def callback_before_save
        @callbacks << :save
      end
      def callback_before_create
        @callbacks << :create
      end
      def callback_before_update
        @callbacks << :update
      end
      def callback_before_destroy
        @callbacks << :destroy
      end
    end
  end
end
describe "class including Harpy::Resource" do
  subject{ Harpy::Spec::Company.new }
  after{ Harpy.reset }
  describe ".from_url(url)" do
    context "called with only one url" do
      let(:url){ "http://localhost/company/1" }
      it "is a properly filled-in instance of Harpy::Spec::Company on success" do
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
      it "is nil when not found" do
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
    context "called with multiple urls" do
      let(:url1){ "http://localhost/company/1" }
      let(:url2){ "http://localhost/company/2" }
      it "is a properly filled-in instance of Harpy::Spec::Company on success" do
        response1 = Typhoeus::Response.new :code => 200, :body => <<-eos
          {
            "name": "Harpy Ltd",
            "link": [
              {"rel": "self", "href": "#{url1}"}
            ]
          }
        eos
        response2 = Typhoeus::Response.new :code => 200, :body => <<-eos
          {
            "name": "Harpy Inc",
            "link": [
              {"rel": "self", "href": "#{url2}"}
            ]
          }
        eos
        Typhoeus::Hydra.hydra.stub(:get, url1).and_return response1
        Typhoeus::Hydra.hydra.stub(:get, url2).and_return response2
        results = Harpy::Spec::Company.from_url [url1, url2]
        results.should have(2).items
        results[0].should be_kind_of Harpy::Spec::Company
        results[0].name.should == "Harpy Ltd"
        results[0].link("self").should == url1
        results[1].should be_kind_of Harpy::Spec::Company
        results[1].name.should == "Harpy Inc"
        results[1].link("self").should == url2
      end
    end
  end
  describe ".from_urn(urn)" do
    context "when entry point is not set" do
      it "raises Harpy::EntryPointRequired" do
        lambda{
          Harpy::Spec::Company.from_urn("urn:harpy:company:1")
        }.should raise_error Harpy::EntryPointRequired
      end
    end
    context "when entry point is set" do
      let(:urn) { "urn:harpy:company:1" }
      let(:url) { "http://localhost/company/1" }
      it "asks Harpy.entry_point to convert urn to url then call .from_url" do
        # urn:harpy:company:1 -> http://localhost/company/1
        Harpy.entry_point = mock
        Harpy.entry_point.should_receive(:urn).with(urn).and_return url

        # http://localhost/company/1 -> Harpy::Spec::Company instance
        Harpy::Spec::Company.should_receive(:from_url).with(url).and_return(expected = mock)
        Harpy::Spec::Company.from_urn(urn).should be expected
      end
      it "is nil if urn is not found" do
        # urn:harpy:company:1 -> nil
        Harpy.entry_point = mock
        Harpy.entry_point.should_receive(:urn).with(urn)
        
        Harpy::Spec::Company.from_urn(urn).should be_nil
      end
    end
  end
  describe ".from_id(id)" do
    context "when urn has not been overriden" do
      it "raises NotImplementedError" do
        lambda{
          Harpy::Spec::Company.from_id(1)
        }.should raise_error NotImplementedError
      end
    end
    context "when urn has been overriden but entry point is not set" do
      let(:urn) { "urn:harpy:company:1" }
      it "raises Harpy::EntryPointRequired" do
        # 1 -> urn:harpy:company:1
        Harpy::Spec::Company.should_receive(:urn).with(1).and_return urn
        
        lambda{
          Harpy::Spec::Company.from_id(1)
        }.should raise_error Harpy::EntryPointRequired
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
      it "is nil if urn is not found" do
        # 1 -> urn:harpy:company:1
        Harpy::Spec::Company.should_receive(:urn).with(1).and_return urn
        
        # urn:harpy:company:1 -> nil
        Harpy.entry_point = mock
        Harpy.entry_point.should_receive(:urn).with(urn)
        
        Harpy::Spec::Company.from_id(1).should be_nil
      end
    end
  end  
  describe ".delete_from_url(url)" do
    context "called with only one url" do
      let(:url){ "http://localhost/company/1" }
      it "is true on success" do
        response = Typhoeus::Response.new :code => 204
        Harpy.client.should_receive(:delete).with(url).and_return response
        result = Harpy::Spec::Company.delete_from_url url
        result.should be_true
      end
      it "is false when not found" do
        response = Typhoeus::Response.new :code => 404
        Harpy.client.should_receive(:delete).with(url).and_return response
        Harpy::Spec::Company.delete_from_url(url).should be_false
      end
      it "delegates response code != 204 or 404 to client" do
        response = Typhoeus::Response.new :code => 500
        Harpy.client.should_receive(:delete).with(url).and_return response
        Harpy.client.should_receive(:invalid_code).with response
        Harpy::Spec::Company.delete_from_url url
      end
    end
  end
  describe ".delete_from_urn(urn)" do
    context "when entry point is not set" do
      it "raises Harpy::EntryPointRequired" do
        lambda{
          Harpy::Spec::Company.delete_from_urn("urn:harpy:company:1")
        }.should raise_error Harpy::EntryPointRequired
      end
    end
    context "when entry point is set" do
      let(:urn) { "urn:harpy:company:1" }
      let(:url) { "http://localhost/company/1" }
      it "asks Harpy.entry_point to convert urn to url then call .from_url" do
        # urn:harpy:company:1 -> http://localhost/company/1
        Harpy.entry_point = mock
        Harpy.entry_point.should_receive(:urn).with(urn).and_return url

        # http://localhost/company/1 -> Harpy::Spec::Company instance
        Harpy::Spec::Company.should_receive(:delete_from_url).with(url).and_return(expected = mock)
        Harpy::Spec::Company.delete_from_urn(urn).should be expected
      end
      it "is nil if urn is not found" do
        # urn:harpy:company:1 -> nil
        Harpy.entry_point = mock
        Harpy.entry_point.should_receive(:urn).with(urn)

        Harpy::Spec::Company.delete_from_urn(urn).should be_false
      end
    end
  end
  describe ".delete_from_id(id)" do
    context "when urn has not been overriden" do
      it "raises NotImplementedError" do
        lambda{
          Harpy::Spec::Company.delete_from_id(1)
        }.should raise_error NotImplementedError
      end
    end
    context "when urn has been overriden but entry point is not set" do
      let(:urn) { "urn:harpy:company:1" }
      it "raises Harpy::EntryPointRequired" do
        # 1 -> urn:harpy:company:1
        Harpy::Spec::Company.should_receive(:urn).with(1).and_return urn
        
        lambda{
          Harpy::Spec::Company.delete_from_id(1)
        }.should raise_error Harpy::EntryPointRequired
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
        Harpy::Spec::Company.should_receive(:delete_from_url).with(url).and_return(expected = mock)
        Harpy::Spec::Company.delete_from_id(1).should be expected
      end
      it "is nil if urn is not found" do
        # 1 -> urn:harpy:company:1
        Harpy::Spec::Company.should_receive(:urn).with(1).and_return urn
        
        # urn:harpy:company:1 -> nil
        Harpy.entry_point = mock
        Harpy.entry_point.should_receive(:urn).with(urn)
        
        Harpy::Spec::Company.delete_from_id(1).should be_false
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
  describe ".resource_name" do
    it "defaults to underscored class name" do
      Harpy::Spec::Company.resource_name.should == "harpy/spec/company"
    end
  end
  describe ".search(conditions)" do
    let(:url){ "http://localhost/company" }
    before do
       Harpy.entry_point = mock
       Harpy.entry_point.should_receive(:resource_url).with("harpy/spec/company").and_return url
    end
    it "return properly filled instances on 200" do
      response = Typhoeus::Response.new :code => 200, :body => <<-eos
      {
        "harpy/spec/company": [
          {
            "firstname": "Anthony",
            "urn": "urn:harpy:company:1",
            "link": [
              {"rel": "self", "href": "#{url}/1"}
            ]
          }
        ],
        "link": [
          {"rel": "self", "href": "#{url}"}
        ]
      }
      eos
      Harpy.client.should_receive(:get).with(url, :params => {"firstname" => "Anthony"}).and_return response
      companies = Harpy::Spec::Company.search "firstname" => "Anthony"
      companies.should be_kind_of Harpy::Collection
      companies.should have(1).item
      companies.should have(1).items
      companies.first.should be_kind_of Harpy::Spec::Company
      companies.first.firstname.should == "Anthony"
      companies.first.id.should == "1"
      companies.url.should == url
      companies.each do |company|
        company.firstname.should == "Anthony"
      end.should be_kind_of Array
      companies.each.should be_kind_of(defined?(Enumerator) ? Enumerator : Enumerable::Enumerator)
      companies.to_a.should == [companies.first]
      companies.detect{ true }.should be companies.first
      companies.should be_present
      companies.should_not be_blank
      companies.replace []
      companies.should_not be_present
      companies.should be_blank
    end
    it "delegates other response codes to client" do
      response = Typhoeus::Response.new :code => 500
      Harpy.client.should_receive(:get).with(url, :params => {}).and_return response
      Harpy.client.should_receive(:invalid_code).with response
      Harpy::Spec::Company.search
    end
  end
  describe ".with_url(url)" do
    let(:url){ "http://localhost/user/1/company" }
    it "overrides url used for searches" do
      response = Typhoeus::Response.new :code => 500
      Harpy.client.should_receive(:get).with(url, :params => {}).and_return response
      Harpy.client.should_receive(:invalid_code).with response
      Harpy::Spec::Company.with_url(url) do
        Harpy::Spec::Company.search
      end
    end
    it "can be nested" do
      url2 = "http://localhost/user/2/company"
      response = Typhoeus::Response.new :code => 500
      Harpy.client.should_receive(:get).ordered.with(url2, :params => {}).and_return response
      Harpy.client.should_receive(:get).ordered.with(url, :params => {}).and_return response
      Harpy.client.should_receive(:invalid_code).twice.with response
      Harpy::Spec::Company.with_url(url) do
        Harpy::Spec::Company.with_url(url2) do
          Harpy::Spec::Company.search
        end
        Harpy::Spec::Company.search
      end
    end
  end
  describe "mass assignment" do
    it "sets any attribute on initialization" do
      company = Harpy::Spec::Company.new "name" => "Harpy Ltd"
      company.name.should == "Harpy Ltd"
    end
    it "initialization works with string keys only" do
      company = Harpy::Spec::Company.new :name => "Harpy Ltd"
      company.name.should be_nil
    end
    it "#attributes=(attrs) merges new attributes with previous ones" do
      company = Harpy::Spec::Company.new "name" => "Harpy Ltd", "deleted" => false
      company.attributes = {"name" => "Harpy Inc", "custom" => true}
      company.name.should eql "Harpy Inc"
      company.deleted.should be_false
      company.custom.should be_true
    end
    it "#attributes=(attrs) works with string keys only" do
      company = Harpy::Spec::Company.new "name" => "Harpy Ltd"
      company.attributes = {:name => "Harpy Inc"}
      company.name.should eql "Harpy Ltd"
    end
    it "doesn't define writers for each attribute" do
      company = Harpy::Spec::Company.new "name" => "Harpy Ltd"
      lambda{ company.name = "test" }.should raise_error NoMethodError
      lambda{ company[1] }.should raise_error NoMethodError
    end
    it "allows accessing undefined attributes when not persisted" do
      subject.name.should be_nil
    end
    it "doesn't allows accessing undefined attributes when not persisted" do
      subject.should_receive(:persisted?).and_return true
      lambda{ subject.name }.should raise_error NoMethodError
    end
    it "use existing setters if available" do
      company = Harpy::Spec::Company.new "tax_id" => "123"
      company.tax_id.should == "123"
      company.as_json.should == {}
      company.attributes = {:tax_id => 123}
      company.tax_id.should == 123
      company.as_json.should == {}
    end
  end
  describe "advanced attribute readers" do
    let(:url){ "http://localhost/company/1" }
    subject{ Harpy::Spec::Company.new "link" => [{"rel" => "self", "href" => url}] }
    describe "#link(rel)" do
      it "searches link with matching rel and return href" do
        subject.link("self").should == url
      end
      it "works with symbols too" do
        subject.link(:self).should == url
      end
      it "is nil if no matching link can be found" do
        subject.link("user").should be_nil
      end
    end
    describe "#url" do
      it "searches url to self inside links" do
        subject.should_receive(:link).with("self").and_return (expected = mock)
        subject.url.should be expected
      end
      it "is nil when no link to self can be found" do
        subject.should_receive(:link).with "self"
        subject.url.should be_nil
      end
    end
    describe "#url_collection" do
      it "defaults to entry_point link which rel matches resource name" do
        Harpy.entry_point = mock
        Harpy.entry_point.should_receive(:resource_url).with("harpy/spec/company").and_return (expected = mock)
        subject.url_collection.should be expected
      end
    end
    describe "#id" do
      it "extracts last part from urn" do
        company = Harpy::Spec::Company.new "urn" => "urn:harpy:company:1"
        company.id.should == "1"
      end
      it "works with alphanumeric ids too" do
        company = Harpy::Spec::Company.new "urn" => "urn:harpy:company:e{39,^"
        company.id.should == "e{39,^"
      end
      it "works with urns having more than 4 parts" do
        company = Harpy::Spec::Company.new "urn" => "urn:harpy:api:company:1"
        company.id.should == "1"
      end
      it "is nil without urn" do
        subject.id.should be_nil
      end
      it "is nil if urn is an empty string" do
        company = Harpy::Spec::Company.new "urn" => ""
        company.id.should be_nil
      end
      it "never uses manually assigned id attribute" do
        company = Harpy::Spec::Company.new "id" => "1"
        company.id.should be_nil
      end
    end
    describe "#persisted?" do
      it "defaults to false when no urn is defined" do
        company = Harpy::Spec::Company.new
        company.persisted?.should be_false
      end
      it "is true when an urn is present" do
        company = Harpy::Spec::Company.new "urn" => "urn:harpy:company:1"
        company.persisted?.should be_true
      end
      it "is false when urn is an empty string" do
        company = Harpy::Spec::Company.new "urn" => ""
        company.persisted?.should be_false
      end
    end
    describe "#inspect" do
      subject { Harpy::Spec::Company.new "firstname" => "Anthony" }
      it "shows class name, attributes, errors and persisted state" do
        subject.inspect.should == '<Harpy::Spec::Company @attrs:{"firstname"=>"Anthony"} @errors:[] persisted:false>'
      end
    end
    describe "#has_key?(key)" do
      it "is true when attribute is present" do
        subject.has_key?("link").should be_true
      end
      it "does accept symbols too" do
        subject.has_key?(:link).should be_true
      end
      it "is true when attribute is an empty string" do
        company = Harpy::Spec::Company.new "urn" => ""
        company.has_key?("urn").should be_true
      end
      it "is false when attribute is not defined" do
        subject.has_key?("custom").should be_false
      end
      it "is false when key matches an existing method but not an attribute" do
        subject.has_key?(:url).should be_false
      end
      it "does not raise error when checking for an undefined attribute even when persisted" do
        subject.stub(:persisted?).and_return true
        subject.has_key?("custom").should be_false
      end
    end
  end
  describe "#valid?" do
    it "has ActiveModel validations" do
      user = Harpy::Spec::User.new "lastname" => "Stark"
      user.should_not be_valid
      user.should have(1).error
      user.errors[:firstname].should =~ ["can't be blank"]
    end
    it "calls before_validation which prevents validation on false" do
      user = Harpy::Spec::User.new
      user.should_not be_valid
      user.should have(:no).error
    end
  end
  describe "#as_json" do
    let(:url) { "http://localhost/user/1" }
    subject do 
      Harpy::Spec::User.new({
        "urn" => "urn:harpy:user:1", 
        "company_name" => "Stark Enterprises", 
        "link" => [{"rel" => "self", "href" => url}],
      })
    end
  
    it "exclude link and urn from attributes" do
      subject.as_json.should == {"company_name" => "Stark Enterprises"}
    end
    it "does not remove link and urn from object attributes" do
      subject.as_json
      subject.urn.should == "urn:harpy:user:1"
      subject.url.should == url
    end
  end
  describe "#save" do
    subject{ Harpy::Spec::User.new "company_name" => "Stark Enterprises" }
    it "is false and does not call before_save callback if not valid" do
      subject.should_receive :valid?
      subject.save.should be_false
      subject.callbacks.should =~ []
    end
    context "on create (valid, not persisted)" do
      let(:url) { "http://localhost/user" }
      let(:body) { '{"company_name":"Stark Enterprises"}' }
      before do
        subject.should_receive(:valid?).and_return true
        subject.should_receive(:url_collection).and_return url
      end
      [200, 201, 302].each do |response_code|
        it "is true and merges response attributes on #{response_code}" do
          response = Typhoeus::Response.new :code => response_code, :body => <<-eos
            {
              "firstname": "Anthony",
              "urn": "urn:harpy:user:1",
              "link": [
                {"rel": "self", "href": "#{url}/1"}
              ]
            }
          eos
          Harpy.client.should_receive(:post).with(url, :body => body).and_return response
          subject.save.should be_true
          subject.callbacks.should =~ [:save, :create]
          subject.firstname.should == "Anthony"
          subject.company_name.should == "Stark Enterprises"
          subject.urn.should == "urn:harpy:user:1"
        end
      end
      it "raises Harpy::InvalidResponseCode on 204" do
        response = Typhoeus::Response.new :code => 204
        Harpy.client.should_receive(:post).with(url, :body => body).and_return response
        lambda { subject.save }.should raise_error Harpy::InvalidResponseCode, "204"
        subject.callbacks.should =~ [:save, :create]
      end
      it "raises Harpy::Unauthorized on 401" do
        response = Typhoeus::Response.new :code => 401
        Harpy.client.should_receive(:post).with(url, :body => body).and_return response
        lambda { subject.save }.should raise_error Harpy::Unauthorized, "Server returned a 401 response code"
        subject.callbacks.should =~ [:save, :create]
      end
      it "is false and fills in errors on 422" do
        response = Typhoeus::Response.new :code => 422, :body => <<-eos
          {
            "firstname": "Anthony",
            "errors": {
              "lastname": ["can't be blank", "must be unique"]
            }
          }
        eos
        Harpy.client.should_receive(:post).with(url, :body => body).and_return response
        subject.save.should be_false
        subject.callbacks.should =~ [:save, :create]
        subject.should have(2).errors
        subject.errors[:lastname].should =~ ["can't be blank", "must be unique"]
        subject.firstname.should be_nil
        subject.company_name.should == "Stark Enterprises"
      end
      it "delegates other response codes to client" do
        response = Typhoeus::Response.new :code => 500
        Harpy.client.should_receive(:post).with(url, :body => body).and_return response
        Harpy.client.should_receive(:invalid_code).with(response)
        subject.save
        subject.callbacks.should =~ [:save, :create]
      end
    end
    context "on update (valid, persisted but link to self is not present)" do
      it "raises Harpy::UrlRequired" do
        subject.should_receive(:valid?).and_return true
        subject.should_receive(:persisted?).and_return true
        lambda{ subject.save }.should raise_error Harpy::UrlRequired
        subject.callbacks.should =~ [:save, :update]
      end
    end
    context "on update (valid, persisted and link to self is present)" do
      let(:url) { "http://localhost/user/1" }
      let(:body) { '{"company_name":"Stark Enterprises"}' }
      subject do
        Harpy::Spec::User.new({
          "urn" => "urn:harpy:user:1", 
          "company_name" => "Stark Enterprises", 
          "link" => [{"rel" => "self", "href" => url}],
        })
      end
      before do
        subject.should_receive(:valid?).and_return true
      end
      [200, 201, 302].each do |response_code|
        it "is true and merges response attributes on #{response_code}" do
          response = Typhoeus::Response.new :code => response_code, :body => <<-eos
            {
              "firstname": "Anthony",
              "urn": "urn:harpy:user:1",
              "link": [
                {"rel": "self", "href": "#{url}/1"}
              ]
            }
          eos
          Harpy.client.should_receive(:put).with(url, :body => body).and_return response
          subject.save.should be_true
          subject.callbacks.should =~ [:save, :update]
          subject.firstname.should == "Anthony"
          subject.company_name.should == "Stark Enterprises"
        end
      end
      it "is true but doesn't touch attributes on 204" do
        response = Typhoeus::Response.new :code => 204
        Harpy.client.should_receive(:put).with(url, :body => body).and_return response
        subject.save.should be_true
        subject.callbacks.should =~ [:save, :update]
        subject.company_name.should == "Stark Enterprises"
      end
      it "raises Harpy::Unauthorized on 401" do
        response = Typhoeus::Response.new :code => 401
        Harpy.client.should_receive(:put).with(url, :body => body).and_return response
        lambda { subject.save }.should raise_error Harpy::Unauthorized, "Server returned a 401 response code"
        subject.callbacks.should =~ [:save, :update]
      end
      it "is false and fills in errors on 422" do
        response = Typhoeus::Response.new :code => 422, :body => <<-eos
          {
            "firstname": "Anthony",
            "errors": {
              "lastname": ["can't be blank", "must be unique"]
            }
          }
        eos
        Harpy.client.should_receive(:put).with(url, :body => body).and_return response
        subject.save.should be_false
        subject.callbacks.should =~ [:save, :update]
        subject.should have(2).errors
        subject.errors[:lastname].should =~ ["can't be blank", "must be unique"]
        lambda { subject.firstname }.should raise_error NoMethodError
        subject.company_name.should == "Stark Enterprises"
      end
      it "delegates other response codes to client" do
        response = Typhoeus::Response.new :code => 500
        Harpy.client.should_receive(:put).with(url, :body => body).and_return response
        Harpy.client.should_receive(:invalid_code).with(response)
        subject.save
        subject.callbacks.should =~ [:save, :update]
      end
    end
  end
  describe "#destroy" do
    subject{ Harpy::Spec::User.new "company_name" => "Stark Enterprises" }
    context "when link to self is missing" do
      it "raises Harpy::UrlRequired" do
        lambda{ subject.destroy }.should raise_error Harpy::UrlRequired
        subject.callbacks.should =~ []
      end
    end
    context "when link to self is present" do
      let(:url) { "http://localhost/user/1" }
      subject do
        Harpy::Spec::User.new({
          "urn" => "urn:harpy:user:1", 
          "company_name" => "Stark Enterprises", 
          "link" => [{"rel" => "self", "href" => url}],
        })
      end
      [200, 201, 302].each do |response_code|
        it "is true and merges response attributes on #{response_code}" do
          response = Typhoeus::Response.new :code => response_code, :body => <<-eos
            {
              "firstname": "Anthony",
              "urn": "urn:harpy:user:1",
              "link": [
                {"rel": "self", "href": "#{url}/1"}
              ]
            }
          eos
          Harpy.client.should_receive(:delete).with(url).and_return response
          subject.destroy.should be_true
          subject.callbacks.should =~ [:destroy]
          subject.firstname.should == "Anthony"
          subject.company_name.should == "Stark Enterprises"
        end
      end
      it "is true but doesn't touch attributes on 204" do
        response = Typhoeus::Response.new :code => 204
        Harpy.client.should_receive(:delete).with(url).and_return response
        subject.destroy.should be_true
        subject.callbacks.should =~ [:destroy]
        subject.company_name.should == "Stark Enterprises"
      end
      it "raises Harpy::Unauthorized on 401" do
        response = Typhoeus::Response.new :code => 401
        Harpy.client.should_receive(:delete).with(url).and_return response
        lambda { subject.destroy }.should raise_error Harpy::Unauthorized, "Server returned a 401 response code"
        subject.callbacks.should =~ [:destroy]
      end
      it "is false and fills in errors on 422" do
        response = Typhoeus::Response.new :code => 422, :body => <<-eos
          {
            "firstname": "Anthony",
            "errors": {
              "lastname": ["can't be blank", "must be unique"]
            }
          }
        eos
        Harpy.client.should_receive(:delete).with(url).and_return response
        subject.destroy.should be_false
        subject.callbacks.should =~ [:destroy]
        subject.should have(2).errors
        subject.errors[:lastname].should =~ ["can't be blank", "must be unique"]
        lambda { subject.firstname }.should raise_error NoMethodError
        subject.company_name.should == "Stark Enterprises"
      end
      it "delegates other response codes to client" do
        response = Typhoeus::Response.new :code => 500
        Harpy.client.should_receive(:delete).with(url).and_return response
        Harpy.client.should_receive(:invalid_code).with(response)
        subject.destroy
        subject.callbacks.should =~ [:destroy]
      end
    end
  end
  describe "equality" do
    it "is equal to itself even without urn" do
      company1 = Harpy::Spec::Company.new
      company2 = company1
      company1.should == company2
    end
    it "two instances without urn are not equal" do
      company1 = Harpy::Spec::Company.new
      company2 = Harpy::Spec::Company.new
      company1.should_not == company2
    end
    it "two instances of the same class with the same urn are equal" do
      company1 = Harpy::Spec::Company.new "urn" => "urn:harpy:company:1"
      company2 = Harpy::Spec::Company.new "urn" => "urn:harpy:company:1"
      company1.should == company2
    end
    it "two instances of the same class with different urns are not equal" do
      company1 = Harpy::Spec::Company.new "urn" => "urn:harpy:company:1"
      company2 = Harpy::Spec::Company.new "urn" => "urn:harpy:company:2"
      company1.should_not == company2
    end
  end
end