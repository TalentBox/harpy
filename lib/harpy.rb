module Harpy
  class Exception < ::Exception; end
  class BodyToBig < Exception; end
  class ClientTimeout < Exception; end
  class ClientError < Exception; end
  class InvalidResponseCode < Exception; end

  autoload :Client, "harpy/client"
  autoload :EntryPoint, "harpy/entry_point"
  autoload :Resource, "harpy/resource"
  autoload :BodyToBig, "harpy/resource"
  autoload :UnknownResponseCode, "harpy/resource"
end
