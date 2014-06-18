require 'quire/version'
require 'quire/sample'

module Quire
  def self.new(source, options = {})
    Quire::Sample.new(source, options)
  end
end
