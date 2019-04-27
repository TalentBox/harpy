require "spec_helper"

describe Harpy::Client do
  let(:entry_url) { "http://localhost" }
  let(:users_url) { "http://localhost/users" }

  context "by default" do
    describe '#options' do
      subject { super().options }
      it { is_expected.to be_empty }
    end
  end

  context "initialized with options" do
    let(:options) { {:username => "harpy", :password => "spec"} }
    subject { Harpy::Client.new(options) }

    describe '#options' do
      subject { super().options }
      it { is_expected.to eq(options) }
    end
  end

  [:get, :head, :post, :put, :patch, :delete].each do |method|
    describe "##{method}(url, opts={})" do
      context "with one url" do
        before do
          @expected = Typhoeus::Response.new :code => 200
          Typhoeus.stub(entry_url, method: method){@expected}
        end
        it "sends a #{method.to_s.upcase} to the url" do
          expect(subject.send(method, entry_url)).to eq(@expected)
        end
        it "merges options" do
          client = Harpy::Client.new :headers => {"Authorization" => "spec"}
          Typhoeus.stub(entry_url, method: method){Typhoeus::Response.new :code => 200}
          response = client.send method, entry_url, :headers => {"X-Files" => "Harpy"}
          expect(response.request.options[:headers]).to include({"X-Files" => "Harpy", "Authorization" => "spec"})
        end
      end
      context "with multiple urls" do
        it "does not execute requests" do
          expect {
            subject.send method, [entry_url, users_url]
          }.not_to raise_error
        end
        it "returns one requests per url" do
          requests = subject.send method, [entry_url, users_url]
          expect(requests.size).to eq(2)
          expect(requests.collect{|r| r.options[:method]}).to match_array([method, method])
          expect(requests.collect(&:url)).to match_array([entry_url, users_url])
        end
        it "merges options" do
          client = Harpy::Client.new :headers => {"Authorization" => "spec"}
          requests = client.send method, [entry_url, users_url], :headers => {"X-Files" => "Harpy"}
          requests.each do |request|
            expect(request.options[:headers]).to include({"X-Files" => "Harpy", "Authorization" => "spec"})
          end
        end
      end
    end
  end
  describe "#run(requests)" do
    before do
      @entry_response = Typhoeus::Response.new :code => 200, :body => "entry"
      @users_response = Typhoeus::Response.new :code => 200, :body => "users"

      Typhoeus.stub(entry_url, method: :get){ @entry_response }
      Typhoeus.stub(users_url, method: :get){ @users_response }
    end
    it "executes requests in parallel" do
      expect(Typhoeus::Hydra.hydra).to receive(:run).once
      subject.run subject.get([entry_url, users_url])
    end
    it "returns responses" do
      responses = subject.run subject.get([entry_url, users_url])
      expect(responses).to match_array([@entry_response, @users_response])
    end
    it "requests response is filled in" do
      requests = subject.get([entry_url, users_url])
      subject.run requests
      expect(requests[0].response).to eq(@entry_response)
      expect(requests[1].response).to eq(@users_response)
    end
  end
  describe "#invalid_code(response)" do
    it "raises Harpy::ClientTimeout on request timeout" do
      expect {
        subject.invalid_code double("Response", :timed_out? => true)
      }.to raise_error Harpy::ClientTimeout
    end
    it "raises Harpy::ClientError on code 0" do
      expect {
        subject.invalid_code double("Response", :timed_out? => false, :code => 0, :return_message => "Could not connect to server")
      }.to raise_error Harpy::ClientError, "Could not connect to server"
    end
    it "raises Harpy::InvalidResponseCode with code otherwise" do
      expect {
        subject.invalid_code double("Response", :timed_out? => false, :code => 404)
      }.to raise_error Harpy::InvalidResponseCode, "404"
    end
  end
end
