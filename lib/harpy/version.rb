# frozen_string_literal: true

require_relative "gem_version"

module Harpy
  def self.version
    gem_version
  end
end
