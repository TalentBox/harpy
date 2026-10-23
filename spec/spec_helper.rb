require "webmock/rspec"
require "httpx"
require "harpy"

WebMock.disable_net_connect!

Dir[File.expand_path("../support/**/*.rb", __FILE__)].each{|f| require f}

module HTTPXSpecHelpers
  def httpx_response(options)
    session = HTTPX::Session.new
    request = session.build_request("GET", "http://localhost")
    headers = options[:headers] || {}
    if headers.is_a?(String)
      headers = headers.lines.each_with_object({}) do |line, parsed|
        name, value = line.split(":", 2)
        parsed[name.strip] = value.strip if value
      end
    end

    response = HTTPX::Response.new(request, options[:code], "1.1", headers)
    response << options[:body] if options[:body]
    response.finish!
    response
  end

  def httpx_error_response(error)
    session = HTTPX::Session.new
    request = session.build_request("GET", "http://localhost")
    HTTPX::ErrorResponse.new(request, error)
  end
end

RSpec.configure do |config|
  config.include HTTPXSpecHelpers
  config.after(:each) do
    WebMock.reset!
  end
end
