require "json"

module Harpy
  class EntryPoint
    attr_accessor :url

    def initialize(url)
      self.url = url
    end

    def resource_url(resource_type)
      response = Harpy.client.get url
      case Harpy.client.response_status(response)
      when 200
        body = JSON.parse response.body
        link = (body["link"] || []).detect{|link| link["rel"] == resource_type}
        link["href"] if link
      else
        Harpy.client.invalid_code response
      end
    end

    def urn(urn)
      response = Harpy.client.get "#{url}/#{urn}"
      case Harpy.client.response_status(response)
      when 301
        response.headers["location"]
      when 404
        nil
      else
        Harpy.client.invalid_code response
      end
    end
  end
end
