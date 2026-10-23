module Harpy
  def self.gem_version
    Gem::Version.new VERSION::STRING
  end

  module VERSION
    MAJOR = 2
    MINOR = 0
    TINY  = 0
    PRE   = "preview1"

    STRING = [MAJOR, MINOR, TINY, PRE].compact.join(".")
  end
end
