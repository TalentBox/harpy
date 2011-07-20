require "harpy/client"
require "active_support"
require "active_support/core_ext/object/blank"
require "active_support/core_ext/numeric/bytes"
require "active_model"
require "yajl"

module Harpy
  module Resource
    extend ActiveSupport::Concern

    included do |base|
      base.extend ActiveModel::Naming
      base.send :include, ActiveModel::Conversion
      base.extend ActiveModel::Translation
      base.extend ActiveModel::Callbacks
      base.send :include, ActiveModel::Validations
      base.send :include, ActiveModel::Validations::Callbacks
      base.define_model_callbacks :save, :create, :update, :destroy, :only => [:before, :after]
    end

    def self.from_url(hash)
      results = {}
      hash.each do |klass, urls|
        results[klass] = Harpy.client.get [*urls]
      end
      Harpy.client.run results.values.flatten
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
          Harpy.client.run(Harpy.client.get url).collect{|response| from_url_handler response}
        else
          from_url_handler Harpy.client.get url
        end
      end

      def from_id(id)
        url = Harpy.entry_point.urn urn(id)
        from_url url if url
      end

      def urn(id)
        raise NotImplementedError
      end

      def resource_name
        name.underscore
      end

      def search(conditions={})
        response = Harpy.client.get url, :params => conditions
        case response.code
        when 200
          parsed = Yajl::Parser.parse response.body
          parsed[resource_name].collect{|model| new model}
        else
          Harpy.client.invalid_code response
        end
      end

      def with_url(url)
        raise ArgumentError unless block_given?
        key = "#{resource_name}_url"
        old, Thread.current[key] = Thread.current[key], url
        result = yield
        Thread.current[key] = old
        result
      end

    private

      def url
        Thread.current["#{resource_name}_url"] || Harpy.entry_point.resource_url(resource_name)
      end

      def from_url_handler(response)
        case response.code
        when 200
          new Yajl::Parser.parse response.body
        when 404
          nil
        else
          Harpy.client.invalid_code response
        end
      end
    end

    module InstanceMethods
      def initialize(attrs = nil)
        @attrs = attrs || {}
      end

      def attributes=(attrs)
        @attrs.merge! attrs
      end
      
      def as_json(*args)
        hash = @attrs.dup
        hash.delete "link"
        hash.delete "urn"
        hash
      end

      def save
        if valid?
          _run_save_callbacks do
            json = Yajl::Encoder.encode as_json
            raise BodyToBig, "Size: #{json.bytesize} bytes (max 1MB)" if json.bytesize > 1.megabyte
            persisted? ? update(json) : create(json)
          end
        else
          false
        end
      end
      
      def destroy
        raise Harpy::UrlRequired unless url
        _run_destroy_callbacks do
          process_response Harpy.client.delete(url), :destroy
        end
      end
      
      def link(rel)
        link = (@attrs["link"]||[]).detect{|l| l["rel"]==rel.to_s}
        link["href"] if link
      end

      def url
        link "self"
      end

      def url_collection
        Harpy.entry_point.resource_url self.class.resource_name
      end

      def id
        @attrs["urn"].split(":").last if @attrs["urn"]
      end

      def persisted?
        @attrs["urn"].present?
      end

      def inspect
        "<#{self.class.name} @attrs:#{@attrs.inspect} @errors:#{errors.inspect} persisted:#{persisted?}>"
      end

      def has_key?(key)
        @attrs.has_key? key.to_s
      end

    private

      def create(json)
        _run_create_callbacks do
          process_response Harpy.client.post(url_collection, :body => json), :create
        end
      end

      def update(json)
        _run_update_callbacks do
          raise Harpy::UrlRequired unless url
          process_response Harpy.client.put(url, :body => json), :update
        end
      end

      def process_response(response, context)
        case response.code
        when 200, 201, 302
          @attrs.merge! Yajl::Parser.parse(response.body)
          true
        when 204
          context==:create ? Harpy.client.invalid_code(response) : true
        when 401
          raise Harpy::Unauthorized, "Server returned a 401 response code"
        when 422
          Yajl::Parser.parse(response.body)["errors"].each do |attr, attr_errors|
            attr_errors.each{|attr_error| errors[attr] = attr_error }
          end
          false
        else
          Harpy.client.invalid_code response
        end
      end

      def method_missing(method, *args)
        key = method.to_s
        if persisted? && !@attrs.has_key?(key)
          super
        elsif key=~/[\]=]\z/
          super
        else
          @attrs[key]
        end
      end
    end
  end
end