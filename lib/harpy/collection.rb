module Harpy
  class Collection
    include Resource
    attr_reader :items
    def initialize(attrs = nil)
      attrs = attrs || {}
      @items = attrs.delete :items
      super attrs
    end
    def persisted?
      true
    end
    alias_method :item, :items
  private
    def method_missing(method, *args)
      if items.respond_to? method
        items.send method, *args
      else
        super
      end
    end
  end
end
