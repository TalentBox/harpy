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
          stub_request(method, entry_url).to_return(status: 200)
        end

        it "sends a #{method.to_s.upcase} to the url" do
          response = subject.send(method, entry_url)
          expect(response.status).to eq(200)
          expect(WebMock).to have_requested(method, entry_url)
        end

        it "merges options" do
          client = Harpy::Client.new :headers => {"Authorization" => "spec"}
          stub_request(method, entry_url).to_return(status: 200)
          response = client.send method, entry_url, :headers => {"X-Files" => "Harpy"}
          expect(WebMock).to have_requested(method, entry_url).with(headers: {
            "X-Files" => "Harpy",
            "Authorization" => "spec"
          })
        end
      end

      context "with multiple urls" do
        it "does not execute requests" do
          expect {
            subject.send method, [entry_url, users_url]
          }.not_to raise_error
        end

        it "returns one request per url" do
          requests = subject.send method, [entry_url, users_url]
          expect(requests.size).to eq(2)
          expect(requests.collect{|request| request.verb.downcase.to_sym}).to match_array([method, method])
          expect(requests.collect{|request| request.uri.to_s}).to match_array([entry_url, users_url])
        end

        it "merges options" do
          client = Harpy::Client.new :headers => {"Authorization" => "spec"}
          requests = client.send method, [entry_url, users_url], :headers => {"X-Files" => "Harpy"}
          requests.each do |request|
            expect(request.headers["x-files"]).to eq("Harpy")
            expect(request.headers["authorization"]).to eq("spec")
          end
        end
      end
    end
  end

  describe "HTTPX request options" do
    it "encodes query parameters" do
      stub_request(:get, "#{users_url}?active=true").to_return(status: 200)

      response = subject.get(users_url, params: {active: true})

      expect(response.status).to eq(200)
      expect(WebMock).to have_requested(:get, "#{users_url}?active=true")
    end

    it "maps username and password to basic authentication" do
      stub_request(:get, entry_url).with(headers: {"Authorization" => "Basic aGFycHk6c3BlYw=="}).to_return(status: 200)

      response = Harpy::Client.new(username: "harpy", password: "spec").get(entry_url)

      expect(response.status).to eq(200)
    end

    it "maps legacy timeout and SSL options" do
      request = Harpy::Client.new(timeout: 5000, ssl_verifypeer: false, ssl_verifyhost: 0).get([entry_url]).first

      expect(request.options.timeout.total_request_timeout).to eq(5)
      expect(request.options.ssl).to include(verify_mode: OpenSSL::SSL::VERIFY_NONE, verify_hostname: false)
    end
  end

  describe "#run(requests)" do
    before do
      stub_request(:get, entry_url).to_return(status: 200, body: "entry")
      stub_request(:get, users_url).to_return(status: 200, body: "users")
    end

    it "submits the requests together to HTTPX" do
      requests = subject.get([entry_url, users_url])
      expect(subject.instance_variable_get(:@session)).to receive(:request).with(*requests).and_call_original
      subject.run requests
    end

    it "returns responses" do
      responses = subject.run subject.get([entry_url, users_url])
      expect(responses.map(&:body)).to match_array(["entry", "users"])
    end

    it "fills in each request response" do
      requests = subject.get([entry_url, users_url])
      subject.run requests
      expect(requests.map{|request| request.response.body}).to eq(["entry", "users"])
    end
  end

  describe "#invalid_code(response)" do
    it "raises Harpy::ClientTimeout on request timeout" do
      error = HTTPX::RequestTimeoutError.new(nil, nil, 1)
      expect {
        subject.invalid_code httpx_error_response(error)
      }.to raise_error Harpy::ClientTimeout
    end

    it "raises Harpy::ClientError on transport error" do
      error = HTTPX::ConnectionError.new("Could not connect to server")
      expect {
        subject.invalid_code httpx_error_response(error)
      }.to raise_error Harpy::ClientError, "Could not connect to server"
    end

    it "raises Harpy::InvalidResponseCode with code otherwise" do
      expect {
        subject.invalid_code httpx_response(:code => 404)
      }.to raise_error Harpy::InvalidResponseCode, "404"
    end
  end
end
