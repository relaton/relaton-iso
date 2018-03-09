require "time"

module Isobib
  module BibliographicDateType
    PUBLISHED = 'published'
    ACCESSED  = 'accessed'
    CREATED   = 'created'
    ACTIVATED = 'activated'
  end

  class BibliographicDate

    # @return [BibliographicDateType]
    attr_accessor :type

    # @return [DateTime]
    attr_accessor :from
    
    # @return [DateTime]
    attr_accessor :to

    # @param type [String]
    # @param from [String]
    # @param to [String]
    def initialize(type:, from:, to: nil)
      @type = type
      @from = DateTime.parse(from)
      @to   = DateTime.parse(to) if to
    end
  end
end