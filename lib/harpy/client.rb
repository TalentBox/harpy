require "typhoeus"
require "hash_deep_merge"

module Harpy
  class Client
    attr_accessor :options

    def initialize(opts=nil)
      self.options = (opts || {})
    end

    def get(url_or_urls, opts=nil)
      request :get, url_or_urls, opts
    end

    def head(url_or_urls, opts=nil)
      request :head, url_or_urls, opts
    end

    def post(url_or_urls, opts=nil)
      request :post, url_or_urls, opts
    end

    def put(url_or_urls, opts=nil)
      request :put, url_or_urls, opts
    end

    def patch(url_or_urls, opts=nil)
      request :patch, url_or_urls, opts
    end

    def delete(url_or_urls, opts=nil)
      request :delete, url_or_urls, opts
    end

    def run(requests)
      requests.each{|request| Typhoeus::Hydra.hydra.queue request}
      Typhoeus::Hydra.hydra.run
      requests.collect(&:response)
    end

    def invalid_code(response)
      if response.timed_out?
        raise ClientTimeout
      elsif response.code.zero?
        raise ClientError, response.curl_error_message
      else
        raise InvalidResponseCode, response.code.to_s
      end
    end

  private

    def request(method, urls, opts=nil)
      opts = options.deep_merge(opts || {})
      case urls
      when Array
        requests = urls.collect do |url|
          Typhoeus::Request.new url, opts.merge(:method => method)
        end
      else
        Typhoeus::Request.run urls, opts.merge(:method => method)
      end
    end
  end
end