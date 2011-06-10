require "harpy/client"
require "active_support"
require "active_support/core_ext/object/blank"
require "active_model"
require "yajl"

module Harpy
  module Resource
    extend ActiveSupport::Concern

    included do |base|
      base.extend ActiveModel::Naming
      base.send :include, ActiveModel::Conversion
      base.extend ActiveModel::Translation
      base.send :attr_reader, :errors
    end

    def self.client=(new_client)
      @@client = new_client
    end

    def self.client
      @@client ||= Client.new
    end

    def self.entry_point=(new_entry_point)
      @@entry_point = new_entry_point
    end

    def self.entry_point
      @@entry_point ||= nil
    end

    def self.from_url(hash)
      results = {}
      hash.each do |klass, urls|
        results[klass] = client.get [*urls]
      end
      client.run results.values.flatten
      results.each do |klass, requests|
        requests.collect! do |request|
          klass.send :from_url_handler, request.response
        end
      end
      results
    end

    module ClassMethods
      def from_url(url)
        case url
        when Array
          client.run(client.get url).collect{|response| from_url_handler response}
        else
          from_url_handler client.get(url)
        end
      end

      def from_id(id)
        url = entry_point.urn urn(id)
        from_url url if url
      end

      def urn(id)
        raise NotImplementedError
      end

    private

      def from_url_handler(response)
        case response.code
        when 200
          new Yajl::Parser.parse response.body
        when 404
          nil
        else
          client.invalid_code response
        end
      end
    end

    module InstanceMethods
      def initialize(attrs = {})
        @persisted = false
        @attrs = attrs
        @errors = {}
      end

      def attributes=(attrs)
        @attrs.merge! attrs
      end

      def save
        json = @attrs.to_json
        raise BodyToBig, "Size: #{json.bytesize} bytes (max 1MB)" if json.bytesize > 1.megabyte
        response = if persisted?
          self.class.client.put url, :body => json
        else
          self.class.client.post url, :body => json
        end

        case response.code
        when 200, 201, 302
          @attrs.merge! Yajl::Parser.parse(response.body)
          on_create
          true
        when 204
          true
        when 401
          false
        when 422
          @errors = Yajl::Parser.parse(response.body)["errors"]
          false
        else
          self.class.client.invalid_code response
        end
      end

      def on_create
      end

      def url
        if link = (@attrs["link"] || []).detect{|l| l["rel"] == "self"}
          link["href"]
        else
          url_collection
        end
      end

      def url_collection
        raise NotImplementedError
      end

      def id
        @attrs["urn"].split(":").last if @attrs["urn"]
      end

      def persisted?
        @attrs["urn"].present?
      end

      def inspect
        "<#{self.class.name} @attrs:#{@attrs.inspect} @errors:#{@errors.inspect} persisted:#{@persisted}>"
      end

      def link(rel)
        link = (@attrs["link"]||[]).detect{|l| l["rel"]==rel.to_s}
        link["href"] if link
      end

      def has_key?(key)
        @attrs.has_key? key.to_s
      end

    private

      def method_missing(method, *args)
        if persisted? && !@attrs.has_key?(method.to_s)
          super
        else
          @attrs[method.to_s]
        end
      end
    end
  end
end