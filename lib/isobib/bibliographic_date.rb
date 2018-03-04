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
    attr_accessor :form
    
    # @return [DateTime]
    attr_accessor :to

    def initialize(type, form)
      @type = type
      @form = form
    end
  end
end