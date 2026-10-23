require "base64"
require "openssl"
require "httpx"
require "hash_deep_merge"

module Harpy
  class Client
    attr_accessor :options

    def initialize(opts=nil)
      self.options = (opts || {})
      @session = HTTPX::Session.new
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
      return [] if requests.empty?

      responses = @session.request(*requests)
      responses.is_a?(Array) ? responses : [responses]
    end

    def response_status(response)
      response.is_a?(HTTPX::ErrorResponse) ? 0 : response.status
    end

    def invalid_code(response)
      if response.is_a?(HTTPX::ErrorResponse)
        if response.error.is_a?(HTTPX::TimeoutError)
          raise ClientTimeout
        else
          raise ClientError, response.error.message
        end
      else
        raise InvalidResponseCode, response.status.to_s
      end
    end

  private

    def request(method, urls, opts=nil)
      opts = httpx_options(options.deep_merge(opts || {}))
      case urls
      when Array
        urls.collect do |url|
          @session.build_request(method, url, opts.dup)
        end
      else
        @session.request(method.to_s.upcase, urls, **opts)
      end
    end

    def httpx_options(opts)
      timeout = opts[:timeout]
      if timeout.is_a?(Numeric)
        opts[:timeout] = {total_request_timeout: timeout.to_f / 1000} if timeout.positive?
        opts.delete(:timeout) unless timeout.positive?
      end

      ssl_options = (opts[:ssl] || {}).dup
      if opts.key?(:ssl_verifypeer)
        verify_peer = opts.delete(:ssl_verifypeer)
        ssl_options[:verify_mode] = verify_peer ? OpenSSL::SSL::VERIFY_PEER : OpenSSL::SSL::VERIFY_NONE
      end
      if opts.key?(:ssl_verifyhost)
        verify_host = opts.delete(:ssl_verifyhost)
        ssl_options[:verify_hostname] = verify_host != false && verify_host != 0
      end
      opts[:ssl] = ssl_options unless ssl_options.empty?

      username = opts.delete(:username)
      password = opts.delete(:password)
      if username || password
        headers = (opts[:headers] || {}).dup
        headers["Authorization"] ||= "Basic #{Base64.strict_encode64("#{username}:#{password}")}"
        opts[:headers] = headers
      end
      opts
    end
  end
end
