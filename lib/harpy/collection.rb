module Harpy
  class Collection
    include Resource
    def initialize(attrs = nil)
      attrs = attrs || {}
      @items = attrs.delete :items
      super attrs
    end
  private
    def method_missing(method, *args)
      if @items.respond_to? method
        @items.send method, *args
      else
        super
      end
    end
  end
end
