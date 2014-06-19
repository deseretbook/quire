require 'zip/filesystem'
require 'multi_xml'

MultiXml.parser = :nokogiri

require 'quire/version'
require 'quire/opf'
require 'quire/toc'
require 'quire/sample'
require 'quire/source'
require 'quire/source/filesystem'
require 'quire/source/http'
require 'quire/source/io'

module Quire
  def self.new(source, options = {})
    Quire::Sample.new(source, options)
  end
end
