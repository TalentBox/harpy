require "spec_helper"

describe Harpy::Resource do
  describe ".from_url(hash)" do
    let(:company_url) { "http://localhost/company/1" }
    let(:json_response) { %Q|{"name": "Harpy ltd", "link": [{"rel": "self", "href": "#{company_url}"}]}| }
    let(:success_response) { Typhoeus::Response.new :code => 200, :body => json_response}
    it "queries multiple resources in parallel and return instances" do
      Typhoeus.stub(company_url, method: :get){ success_response }
      responses = Harpy::Resource.from_url({ Harpy::Spec::Company => [company_url] })
      expect(responses.size).to eq(1)
      expect(responses[Harpy::Spec::Company].size).to eq(1)
      expect(responses[Harpy::Spec::Company].first.name).to eq("Harpy ltd")
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
        throw :abort unless lastname
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
        expect(Harpy.client).to receive(:get).with(url).and_return response
        result = Harpy::Spec::Company.from_url url
        expect(result).to be_kind_of Harpy::Spec::Company
        expect(result.name).to eq("Harpy Ltd")
        expect(result.link("self")).to eq(url)
      end
      it "is nil when not found" do
        response = Typhoeus::Response.new :code => 404
        expect(Harpy.client).to receive(:get).with(url).and_return response
        expect(Harpy::Spec::Company.from_url(url)).to be_nil
      end
      it "delegates response code != 200 or 404 to client" do
        response = Typhoeus::Response.new :code => 500
        expect(Harpy.client).to receive(:get).with(url).and_return response
        expect(Harpy.client).to receive(:invalid_code).with response
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
        Typhoeus.stub(url1, method: :get){ response1 }
        Typhoeus.stub(url2, method: :get){ response2 }
        results = Harpy::Spec::Company.from_url [url1, url2]
        expect(results.size).to eq(2)
        expect(results[0]).to be_kind_of Harpy::Spec::Company
        expect(results[0].name).to eq("Harpy Ltd")
        expect(results[0].link("self")).to eq(url1)
        expect(results[1]).to be_kind_of Harpy::Spec::Company
        expect(results[1].name).to eq("Harpy Inc")
        expect(results[1].link("self")).to eq(url2)
      end
    end
  end
  describe ".from_urn(urn)" do
    context "when entry point is not set" do
      it "raises Harpy::EntryPointRequired" do
        expect{
          Harpy::Spec::Company.from_urn("urn:harpy:company:1")
        }.to raise_error Harpy::EntryPointRequired
      end
    end
    context "when entry point is set" do
      let(:urn) { "urn:harpy:company:1" }
      let(:url) { "http://localhost/company/1" }
      it "asks Harpy.entry_point to convert urn to url then call .from_url" do
        # urn:harpy:company:1 -> http://localhost/company/1
        Harpy.entry_point = double
        expect(Harpy.entry_point).to receive(:urn).with(urn).and_return url

        # http://localhost/company/1 -> Harpy::Spec::Company instance
        expect(Harpy::Spec::Company).to receive(:from_url).with(url).and_return(expected = double)
        expect(Harpy::Spec::Company.from_urn(urn)).to be expected
      end
      it "is nil if urn is not found" do
        # urn:harpy:company:1 -> nil
        Harpy.entry_point = double
        expect(Harpy.entry_point).to receive(:urn).with(urn)

        expect(Harpy::Spec::Company.from_urn(urn)).to be_nil
      end
    end
  end
  describe ".from_id(id)" do
    context "when urn has not been overriden" do
      it "raises NotImplementedError" do
        expect{
          Harpy::Spec::Company.from_id(1)
        }.to raise_error NotImplementedError
      end
    end
    context "when urn has been overriden but entry point is not set" do
      let(:urn) { "urn:harpy:company:1" }
      it "raises Harpy::EntryPointRequired" do
        # 1 -> urn:harpy:company:1
        expect(Harpy::Spec::Company).to receive(:urn).with(1).and_return urn

        expect{
          Harpy::Spec::Company.from_id(1)
        }.to raise_error Harpy::EntryPointRequired
      end
    end
    context "when entry point is set and urn has been overriden" do
      let(:urn) { "urn:harpy:company:1" }
      let(:url) { "http://localhost/company/1" }
      it "asks Harpy.entry_point to convert urn to url then call .from_url" do
        # 1 -> urn:harpy:company:1
        expect(Harpy::Spec::Company).to receive(:urn).with(1).and_return urn

        # urn:harpy:company:1 -> http://localhost/company/1
        Harpy.entry_point = double
        expect(Harpy.entry_point).to receive(:urn).with(urn).and_return url

        # http://localhost/company/1 -> Harpy::Spec::Company instance
        expect(Harpy::Spec::Company).to receive(:from_url).with(url).and_return(expected = double)
        expect(Harpy::Spec::Company.from_id(1)).to be expected
      end
      it "is nil if urn is not found" do
        # 1 -> urn:harpy:company:1
        expect(Harpy::Spec::Company).to receive(:urn).with(1).and_return urn

        # urn:harpy:company:1 -> nil
        Harpy.entry_point = double
        expect(Harpy.entry_point).to receive(:urn).with(urn)

        expect(Harpy::Spec::Company.from_id(1)).to be_nil
      end
    end
  end
  describe ".delete_from_url(url)" do
    context "called with only one url" do
      let(:url){ "http://localhost/company/1" }
      it "is true on success" do
        response = Typhoeus::Response.new :code => 204
        expect(Harpy.client).to receive(:delete).with(url).and_return response
        result = Harpy::Spec::Company.delete_from_url url
        expect(result).to be_truthy
      end
      it "is false when not found" do
        response = Typhoeus::Response.new :code => 404
        expect(Harpy.client).to receive(:delete).with(url).and_return response
        expect(Harpy::Spec::Company.delete_from_url(url)).to be_falsey
      end
      it "delegates response code != 204 or 404 to client" do
        response = Typhoeus::Response.new :code => 500
        expect(Harpy.client).to receive(:delete).with(url).and_return response
        expect(Harpy.client).to receive(:invalid_code).with response
        Harpy::Spec::Company.delete_from_url url
      end
    end
  end
  describe ".delete_from_urn(urn)" do
    context "when entry point is not set" do
      it "raises Harpy::EntryPointRequired" do
        expect{
          Harpy::Spec::Company.delete_from_urn("urn:harpy:company:1")
        }.to raise_error Harpy::EntryPointRequired
      end
    end
    context "when entry point is set" do
      let(:urn) { "urn:harpy:company:1" }
      let(:url) { "http://localhost/company/1" }
      it "asks Harpy.entry_point to convert urn to url then call .from_url" do
        # urn:harpy:company:1 -> http://localhost/company/1
        Harpy.entry_point = double
        expect(Harpy.entry_point).to receive(:urn).with(urn).and_return url

        # http://localhost/company/1 -> Harpy::Spec::Company instance
        expect(Harpy::Spec::Company).to receive(:delete_from_url).with(url).and_return(expected = double)
        expect(Harpy::Spec::Company.delete_from_urn(urn)).to be expected
      end
      it "is nil if urn is not found" do
        # urn:harpy:company:1 -> nil
        Harpy.entry_point = double
        expect(Harpy.entry_point).to receive(:urn).with(urn)

        expect(Harpy::Spec::Company.delete_from_urn(urn)).to be_falsey
      end
    end
  end
  describe ".delete_from_id(id)" do
    context "when urn has not been overriden" do
      it "raises NotImplementedError" do
        expect{
          Harpy::Spec::Company.delete_from_id(1)
        }.to raise_error NotImplementedError
      end
    end
    context "when urn has been overriden but entry point is not set" do
      let(:urn) { "urn:harpy:company:1" }
      it "raises Harpy::EntryPointRequired" do
        # 1 -> urn:harpy:company:1
        expect(Harpy::Spec::Company).to receive(:urn).with(1).and_return urn

        expect{
          Harpy::Spec::Company.delete_from_id(1)
        }.to raise_error Harpy::EntryPointRequired
      end
    end
    context "when entry point is set and urn has been overriden" do
      let(:urn) { "urn:harpy:company:1" }
      let(:url) { "http://localhost/company/1" }
      it "asks Harpy.entry_point to convert urn to url then call .from_url" do
        # 1 -> urn:harpy:company:1
        expect(Harpy::Spec::Company).to receive(:urn).with(1).and_return urn

        # urn:harpy:company:1 -> http://localhost/company/1
        Harpy.entry_point = double
        expect(Harpy.entry_point).to receive(:urn).with(urn).and_return url

        # http://localhost/company/1 -> Harpy::Spec::Company instance
        expect(Harpy::Spec::Company).to receive(:delete_from_url).with(url).and_return(expected = double)
        expect(Harpy::Spec::Company.delete_from_id(1)).to be expected
      end
      it "is nil if urn is not found" do
        # 1 -> urn:harpy:company:1
        expect(Harpy::Spec::Company).to receive(:urn).with(1).and_return urn

        # urn:harpy:company:1 -> nil
        Harpy.entry_point = double
        expect(Harpy.entry_point).to receive(:urn).with(urn)

        expect(Harpy::Spec::Company.delete_from_id(1)).to be_falsey
      end
    end
  end
  describe ".urn(id)" do
    it "raises NotImplementedError" do
      expect{
        Harpy::Spec::Company.urn(1)
      }.to raise_error NotImplementedError
    end
  end
  describe ".resource_name" do
    it "defaults to underscored class name" do
      expect(Harpy::Spec::Company.resource_name).to eq("harpy/spec/company")
    end
  end
  describe ".search(conditions)" do
    let(:url){ "http://localhost/company" }
    before do
       Harpy.entry_point = double
       expect(Harpy.entry_point).to receive(:resource_url).with("harpy/spec/company").and_return url
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
      expect(Harpy.client).to receive(:get).with(url, :params => {"firstname" => "Anthony"}).and_return response
      companies = Harpy::Spec::Company.search "firstname" => "Anthony"
      expect(companies).to be_kind_of Harpy::Collection
      expect(companies.size).to eq(1)
      expect(companies.size).to eq(1)
      expect(companies.first).to be_kind_of Harpy::Spec::Company
      expect(companies.first.firstname).to eq("Anthony")
      expect(companies.first.id).to eq("1")
      expect(companies.url).to eq(url)
      expect(companies.each do |company|
        expect(company.firstname).to eq("Anthony")
      end).to be_kind_of Array
      expect(companies.each).to be_kind_of(defined?(Enumerator) ? Enumerator : Enumerable::Enumerator)
      expect(companies.to_a).to eq([companies.first])
      expect(companies.detect{ true }).to be companies.first
      expect(companies.present?).to be true
      expect(companies.blank?).not_to be true
      companies.replace []
      expect(companies.present?).not_to be true
      expect(companies.blank?).to be true
    end
    it "delegates other response codes to client" do
      response = Typhoeus::Response.new :code => 500
      expect(Harpy.client).to receive(:get).with(url, :params => {}).and_return response
      expect(Harpy.client).to receive(:invalid_code).with response
      Harpy::Spec::Company.search
    end
  end
  describe ".with_url(url)" do
    let(:url){ "http://localhost/user/1/company" }
    it "overrides url used for searches" do
      response = Typhoeus::Response.new :code => 500
      expect(Harpy.client).to receive(:get).with(url, :params => {}).and_return response
      expect(Harpy.client).to receive(:invalid_code).with response
      Harpy::Spec::Company.with_url(url) do
        Harpy::Spec::Company.search
      end
    end
    it "can be nested" do
      url2 = "http://localhost/user/2/company"
      response = Typhoeus::Response.new :code => 500
      expect(Harpy.client).to receive(:get).ordered.with(url2, :params => {}).and_return response
      expect(Harpy.client).to receive(:get).ordered.with(url, :params => {}).and_return response
      expect(Harpy.client).to receive(:invalid_code).twice.with response
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
      expect(company.name).to eq("Harpy Ltd")
    end
    it "initialization works with string keys only" do
      company = Harpy::Spec::Company.new :name => "Harpy Ltd"
      expect(company.name).to be_nil
    end
    it "#attributes=(attrs) merges new attributes with previous ones" do
      company = Harpy::Spec::Company.new "name" => "Harpy Ltd", "deleted" => false
      company.attributes = {"name" => "Harpy Inc", "custom" => true}
      expect(company.name).to eql "Harpy Inc"
      expect(company.deleted).to be_falsey
      expect(company.custom).to be_truthy
    end
    it "#attributes=(attrs) works with string keys only" do
      company = Harpy::Spec::Company.new "name" => "Harpy Ltd"
      company.attributes = {:name => "Harpy Inc"}
      expect(company.name).to eql "Harpy Ltd"
    end
    it "doesn't define writers for each attribute" do
      company = Harpy::Spec::Company.new "name" => "Harpy Ltd"
      expect{ company.name = "test" }.to raise_error NoMethodError
      expect{ company[1] }.to raise_error NoMethodError
    end
    it "allows accessing undefined attributes when not persisted" do
      expect(subject.name).to be_nil
    end
    it "doesn't allows accessing undefined attributes when not persisted" do
      expect(subject).to receive(:persisted?).and_return true
      expect{ subject.name }.to raise_error NoMethodError
    end
    it "use existing setters if available" do
      company = Harpy::Spec::Company.new "tax_id" => "123"
      expect(company.tax_id).to eq("123")
      expect(company.as_json).to eq({})
      company.attributes = {:tax_id => 123}
      expect(company.tax_id).to eq(123)
      expect(company.as_json).to eq({})
    end
  end
  describe "advanced attribute readers" do
    let(:url){ "http://localhost/company/1" }
    subject{ Harpy::Spec::Company.new "link" => [{"rel" => "self", "href" => url}] }
    describe "#link(rel)" do
      it "searches link with matching rel and return href" do
        expect(subject.link("self")).to eq(url)
      end
      it "works with symbols too" do
        expect(subject.link(:self)).to eq(url)
      end
      it "is nil if no matching link can be found" do
        expect(subject.link("user")).to be_nil
      end
    end
    describe "#url" do
      it "searches url to self inside links" do
        expect(subject).to receive(:link).with("self").and_return (expected = double)
        expect(subject.url).to be expected
      end
      it "is nil when no link to self can be found" do
        expect(subject).to receive(:link).with "self"
        expect(subject.url).to be_nil
      end
    end
    describe "#url_collection" do
      it "defaults to entry_point link which rel matches resource name" do
        Harpy.entry_point = double
        expect(Harpy.entry_point).to receive(:resource_url).with("harpy/spec/company").and_return (expected = double)
        expect(subject.url_collection).to be expected
      end
    end
    describe "#id" do
      it "extracts last part from urn" do
        company = Harpy::Spec::Company.new "urn" => "urn:harpy:company:1"
        expect(company.id).to eq("1")
      end
      it "works with alphanumeric ids too" do
        company = Harpy::Spec::Company.new "urn" => "urn:harpy:company:e{39,^"
        expect(company.id).to eq("e{39,^")
      end
      it "works with urns having more than 4 parts" do
        company = Harpy::Spec::Company.new "urn" => "urn:harpy:api:company:1"
        expect(company.id).to eq("1")
      end
      it "is nil without urn" do
        expect(subject.id).to be_nil
      end
      it "is nil if urn is an empty string" do
        company = Harpy::Spec::Company.new "urn" => ""
        expect(company.id).to be_nil
      end
      it "never uses manually assigned id attribute" do
        company = Harpy::Spec::Company.new "id" => "1"
        expect(company.id).to be_nil
      end
    end
    describe "#persisted?" do
      it "defaults to false when no urn is defined" do
        company = Harpy::Spec::Company.new
        expect(company.persisted?).to be_falsey
      end
      it "is true when an urn is present" do
        company = Harpy::Spec::Company.new "urn" => "urn:harpy:company:1"
        expect(company.persisted?).to be_truthy
      end
      it "is false when urn is an empty string" do
        company = Harpy::Spec::Company.new "urn" => ""
        expect(company.persisted?).to be_falsey
      end
    end
    describe "#inspect" do
      subject { Harpy::Spec::Company.new "firstname" => "Anthony" }
      it "shows class name, attributes, errors and persisted state" do
        expect(subject.inspect).to eq('<Harpy::Spec::Company @attrs:{"firstname"=>"Anthony"} @errors:[] persisted:false>')
      end
    end
    describe "#has_key?(key)" do
      it "is true when attribute is present" do
        expect(subject.has_key?("link")).to be_truthy
      end
      it "does accept symbols too" do
        expect(subject.has_key?(:link)).to be_truthy
      end
      it "is true when attribute is an empty string" do
        company = Harpy::Spec::Company.new "urn" => ""
        expect(company.has_key?("urn")).to be_truthy
      end
      it "is false when attribute is not defined" do
        expect(subject.has_key?("custom")).to be_falsey
      end
      it "is false when key matches an existing method but not an attribute" do
        expect(subject.has_key?(:url)).to be_falsey
      end
      it "does not raise error when checking for an undefined attribute even when persisted" do
        allow(subject).to receive(:persisted?).and_return true
        expect(subject.has_key?("custom")).to be_falsey
      end
    end
  end
  describe "#valid?" do
    it "has ActiveModel validations" do
      user = Harpy::Spec::User.new "lastname" => "Stark"
      expect(user).not_to be_valid
      expect(user.errors.size).to eq(1)
      expect(user.errors[:firstname]).to match_array(["can't be blank"])
    end
    it "calls before_validation which prevents validation on throw" do
      user = Harpy::Spec::User.new
      expect(user).not_to be_valid
      expect(user.errors.size).to eq(0)
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
      expect(subject.as_json).to eq({"company_name" => "Stark Enterprises"})
    end
    it "does not remove link and urn from object attributes" do
      subject.as_json
      expect(subject.urn).to eq("urn:harpy:user:1")
      expect(subject.url).to eq(url)
    end
  end
  describe "#save" do
    subject{ Harpy::Spec::User.new "company_name" => "Stark Enterprises" }
    it "is false and does not call before_save callback if not valid" do
      expect(subject).to receive :valid?
      expect(subject.save).to be_falsey
      expect(subject.callbacks).to match_array([])
    end
    context "on create (valid, not persisted)" do
      let(:url) { "http://localhost/user" }
      let(:body) { '{"company_name":"Stark Enterprises"}' }
      before do
        expect(subject).to receive(:valid?).and_return true
        expect(subject).to receive(:url_collection).and_return url
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
          expect(Harpy.client).to receive(:post).with(url, :body => body).and_return response
          expect(subject.save).to be_truthy
          expect(subject.callbacks).to match_array([:save, :create])
          expect(subject.firstname).to eq("Anthony")
          expect(subject.company_name).to eq("Stark Enterprises")
          expect(subject.urn).to eq("urn:harpy:user:1")
        end
      end
      it "raises Harpy::InvalidResponseCode on 204" do
        response = Typhoeus::Response.new :code => 204
        expect(Harpy.client).to receive(:post).with(url, :body => body).and_return response
        expect { subject.save }.to raise_error Harpy::InvalidResponseCode, "204"
        expect(subject.callbacks).to match_array([:save, :create])
      end
      it "raises Harpy::Unauthorized on 401" do
        response = Typhoeus::Response.new :code => 401
        expect(Harpy.client).to receive(:post).with(url, :body => body).and_return response
        expect { subject.save }.to raise_error Harpy::Unauthorized, "Server returned a 401 response code"
        expect(subject.callbacks).to match_array([:save, :create])
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
        expect(Harpy.client).to receive(:post).with(url, :body => body).and_return response
        expect(subject.save).to be_falsey
        expect(subject.callbacks).to match_array([:save, :create])
        expect(subject.errors.size).to eq(2)
        expect(subject.errors[:lastname]).to match_array(["can't be blank", "must be unique"])
        expect(subject.firstname).to be_nil
        expect(subject.company_name).to eq("Stark Enterprises")
      end
      it "delegates other response codes to client" do
        response = Typhoeus::Response.new :code => 500
        expect(Harpy.client).to receive(:post).with(url, :body => body).and_return response
        expect(Harpy.client).to receive(:invalid_code).with(response)
        subject.save
        expect(subject.callbacks).to match_array([:save, :create])
      end
    end
    context "on update (valid, persisted but link to self is not present)" do
      it "raises Harpy::UrlRequired" do
        expect(subject).to receive(:valid?).and_return true
        expect(subject).to receive(:persisted?).and_return true
        expect{ subject.save }.to raise_error Harpy::UrlRequired
        expect(subject.callbacks).to match_array([:save, :update])
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
        expect(subject).to receive(:valid?).and_return true
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
          expect(Harpy.client).to receive(:put).with(url, :body => body).and_return response
          expect(subject.save).to be_truthy
          expect(subject.callbacks).to match_array([:save, :update])
          expect(subject.firstname).to eq("Anthony")
          expect(subject.company_name).to eq("Stark Enterprises")
        end
      end
      it "is true but doesn't touch attributes on 204" do
        response = Typhoeus::Response.new :code => 204
        expect(Harpy.client).to receive(:put).with(url, :body => body).and_return response
        expect(subject.save).to be_truthy
        expect(subject.callbacks).to match_array([:save, :update])
        expect(subject.company_name).to eq("Stark Enterprises")
      end
      it "raises Harpy::Unauthorized on 401" do
        response = Typhoeus::Response.new :code => 401
        expect(Harpy.client).to receive(:put).with(url, :body => body).and_return response
        expect { subject.save }.to raise_error Harpy::Unauthorized, "Server returned a 401 response code"
        expect(subject.callbacks).to match_array([:save, :update])
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
        expect(Harpy.client).to receive(:put).with(url, :body => body).and_return response
        expect(subject.save).to be_falsey
        expect(subject.callbacks).to match_array([:save, :update])
        expect(subject.errors.size).to eq(2)
        expect(subject.errors[:lastname]).to match_array(["can't be blank", "must be unique"])
        expect { subject.firstname }.to raise_error NoMethodError
        expect(subject.company_name).to eq("Stark Enterprises")
      end
      it "delegates other response codes to client" do
        response = Typhoeus::Response.new :code => 500
        expect(Harpy.client).to receive(:put).with(url, :body => body).and_return response
        expect(Harpy.client).to receive(:invalid_code).with(response)
        subject.save
        expect(subject.callbacks).to match_array([:save, :update])
      end
    end
  end
  describe "#destroy" do
    subject{ Harpy::Spec::User.new "company_name" => "Stark Enterprises" }
    context "when link to self is missing" do
      it "raises Harpy::UrlRequired" do
        expect{ subject.destroy }.to raise_error Harpy::UrlRequired
        expect(subject.callbacks).to match_array([])
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
          expect(Harpy.client).to receive(:delete).with(url).and_return response
          expect(subject.destroy).to be_truthy
          expect(subject.callbacks).to match_array([:destroy])
          expect(subject.firstname).to eq("Anthony")
          expect(subject.company_name).to eq("Stark Enterprises")
        end
      end
      it "is true but doesn't touch attributes on 204" do
        response = Typhoeus::Response.new :code => 204
        expect(Harpy.client).to receive(:delete).with(url).and_return response
        expect(subject.destroy).to be_truthy
        expect(subject.callbacks).to match_array([:destroy])
        expect(subject.company_name).to eq("Stark Enterprises")
      end
      it "raises Harpy::Unauthorized on 401" do
        response = Typhoeus::Response.new :code => 401
        expect(Harpy.client).to receive(:delete).with(url).and_return response
        expect { subject.destroy }.to raise_error Harpy::Unauthorized, "Server returned a 401 response code"
        expect(subject.callbacks).to match_array([:destroy])
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
        expect(Harpy.client).to receive(:delete).with(url).and_return response
        expect(subject.destroy).to be_falsey
        expect(subject.callbacks).to match_array([:destroy])
        expect(subject.errors.size).to eq(2)
        expect(subject.errors[:lastname]).to match_array(["can't be blank", "must be unique"])
        expect { subject.firstname }.to raise_error NoMethodError
        expect(subject.company_name).to eq("Stark Enterprises")
      end
      it "delegates other response codes to client" do
        response = Typhoeus::Response.new :code => 500
        expect(Harpy.client).to receive(:delete).with(url).and_return response
        expect(Harpy.client).to receive(:invalid_code).with(response)
        subject.destroy
        expect(subject.callbacks).to match_array([:destroy])
      end
    end
  end
  describe "equality" do
    it "is equal to itself even without urn" do
      company1 = Harpy::Spec::Company.new
      company2 = company1
      expect(company1).to eq(company2)
    end
    it "two instances without urn are not equal" do
      company1 = Harpy::Spec::Company.new
      company2 = Harpy::Spec::Company.new
      expect(company1).not_to eq(company2)
    end
    it "two instances of the same class with the same urn are equal" do
      company1 = Harpy::Spec::Company.new "urn" => "urn:harpy:company:1"
      company2 = Harpy::Spec::Company.new "urn" => "urn:harpy:company:1"
      expect(company1).to eq(company2)
    end
    it "two instances of the same class with different urns are not equal" do
      company1 = Harpy::Spec::Company.new "urn" => "urn:harpy:company:1"
      company2 = Harpy::Spec::Company.new "urn" => "urn:harpy:company:2"
      expect(company1).not_to eq(company2)
    end
  end
end
