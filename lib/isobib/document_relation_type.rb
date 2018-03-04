module Isobib
  module DocumentRelationType
    PARENT        = 'parent'
    CHILD         = 'child'
    OBSOLETES     = 'obsoletes'
    UPDATES       = 'updates'
    COMPLEMENTS   = 'complements'
    DERIVED_FORM  = 'derivedForm'
    ADOPTED_FORM  = 'adoptedForm'
    EQUIVALENT    = 'equivalent'
    IDENTICAL     = 'identical'
    NONEQUIVALENT = 'nonequivalent'
  end

  class DocumentRelationType
    # @return [DocumentRelationType]
    attr_accessor :type

    # @return [BibliographicItem]
    attr_accessor :bibitem

    # @return [Array<BibItemLocality>]
    attr_accessor :bib_locality

    def initialize(type, bibitem)
      @type         = type
      @bibitem      = bibitem
      @bib_locality = []
    end
  end
end