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
    undef :blank?
    alias_method :item, :items
    alias_method :to_a, :items
    alias_method :to_ary, :items
  private
    def method_missing(method, *args, &blk)
      if items.respond_to? method
        items.send method, *args, &blk
      else
        super
      end
    end
  end
end
