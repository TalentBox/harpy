module Harpy
  class Exception < ::Exception; end
  class EntryPointRequired < Exception; end
  class BodyToBig < Exception; end
  class ClientTimeout < Exception; end
  class ClientError < Exception; end
  class InvalidResponseCode < Exception; end

  autoload :Client, "harpy/client"
  autoload :EntryPoint, "harpy/entry_point"
  autoload :Resource, "harpy/resource"
  autoload :BodyToBig, "harpy/resource"
  autoload :UnknownResponseCode, "harpy/resource"

  def self.client=(new_client)
    @client = new_client
  end

  def self.client
    @client ||= Client.new
  end

  def self.entry_point_url=(url)
    @entry_point = EntryPoint.new url
  end

  def self.entry_point_url
    @entry_point.url if @entry_point
  end

  def self.entry_point=(value)
    @entry_point = value
  end

  def self.entry_point
    @entry_point || raise(EntryPointRequired, 'you can setup one with Harpy.entry_point_url = "http://localhost"')
  end
  
  def self.reset
    @client = nil
    @entry_point = nil
  end

end