require "spec_helper"

describe Harpy::Client do
  let(:entry_url) { "http://localhost" }
  let(:users_url) { "http://localhost/users" }

  context "by default" do
    its(:options) { should be_empty }
  end

  context "initialized with options" do
    let(:options) { {:username => "harpy", :password => "spec"} }
    subject { Harpy::Client.new(options) }
    its(:options) { should == options }
  end

  [:get, :head, :post, :put, :patch, :delete].each do |method|
    describe "##{method}(url, opts={})" do
      context "with one url" do
        before do
          @expected = Typhoeus::Response.new :code => 200
          Typhoeus::Hydra.hydra.stub(method, entry_url).and_return(@expected)
        end
        it "sends a #{method.upcase} to the url" do
          subject.send(method, entry_url).should == @expected
        end
        it "merges options" do
          client = Harpy::Client.new :headers => {"Authorization" => "spec"}
          Typhoeus::Hydra.hydra.stub(method, entry_url).and_return(Typhoeus::Response.new :code => 200)
          response = client.send method, entry_url, :headers => {"X-Files" => "Harpy"}
          response.request.headers.should include({"X-Files" => "Harpy", "Authorization" => "spec"})
        end
      end
      context "with multiple urls" do
        it "does not execute requests" do
          lambda {
            subject.send method, [entry_url, users_url]
          }.should_not raise_error Typhoeus::Hydra::NetConnectNotAllowedError
        end
        it "returns one requests per url" do
          requests = subject.send method, [entry_url, users_url]
          requests.size.should == 2
          requests.collect(&:method).should =~ [method, method]
          requests.collect(&:url).should =~ [entry_url, users_url]
        end
        it "merges options" do
          client = Harpy::Client.new :headers => {"Authorization" => "spec"}
          requests = client.send method, [entry_url, users_url], :headers => {"X-Files" => "Harpy"}
          requests.each do |request|
            request.headers.should include({"X-Files" => "Harpy", "Authorization" => "spec"})
          end
        end
      end
    end
  end
  describe "#run(requests)" do
    before do
      @entry_response = Typhoeus::Response.new :code => 200, :body => "entry"
      @users_response = Typhoeus::Response.new :code => 200, :body => "users"
      
      Typhoeus::Hydra.hydra.stub(:get, entry_url).and_return @entry_response
      Typhoeus::Hydra.hydra.stub(:get, users_url).and_return @users_response
    end
    it "executes requests in parallel" do
      Typhoeus::Hydra.hydra.should_receive(:run).once
      subject.run subject.get([entry_url, users_url])
    end
    it "returns responses" do
      responses = subject.run subject.get([entry_url, users_url])
      responses.should =~ [@entry_response, @users_response]
    end
    it "requests response is filled in" do
      requests = subject.get([entry_url, users_url])
      subject.run requests
      requests[0].response.should == @entry_response
      requests[1].response.should == @users_response
    end
  end
  describe "#invalid_code(response)" do
    it "raises Harpy::ClientTimeout on request timeout" do
      lambda {
        subject.invalid_code mock("Response", :timed_out? => true)
      }.should raise_error Harpy::ClientTimeout
    end
    it "raises Harpy::ClientError on code 0" do
      lambda {
        subject.invalid_code mock("Response", :timed_out? => false, :code => 0, :curl_error_message => "Could not connect to server")
      }.should raise_error Harpy::ClientError, "Could not connect to server"
    end
    it "raises Harpy::InvalidResponseCode with code otherwise" do
      lambda {
        subject.invalid_code mock("Response", :timed_out? => false, :code => 404)
      }.should raise_error Harpy::InvalidResponseCode, "404"
    end
  end
end