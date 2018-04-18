require "nokogiri"

module Isobib
  class Serialiser
    def self.serialise
      builder = Nokogiri::XML::Builder.new()
    end   
  end
end