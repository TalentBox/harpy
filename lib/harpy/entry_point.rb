require "harpy/client"
require "yajl"

module Harpy
  class EntryPoint
    attr_accessor :client
    attr_accessor :url

    def initialize(client, url)
      self.client = client
      self.url = url
    end

    def resource_url(resource_type)
      response = client.get url
      case response.code
      when 200
        body = Yajl::Parser.parse response.body
        link = (body["link"] || []).detect{|link| link["rel"] == resource_type}
        link["href"] if link
      else
        client.invalid_code response
      end
    end

    def urn(urn)
      response = client.get "#{url}/#{urn}"
      case response.code
      when 301
        response.headers_hash["Location"]
      when 404
        nil
      else
        client.invalid_code response
      end
    end
  end
end