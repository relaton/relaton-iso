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

  class SpecificLocalityType
    SECTION   = "section"
    CLAUSE    = "clause"
    PART      = "part"
    PARAGRAPH = "paragraph"
    CHAPTER   = "chapter"
    PAGE      = "page"
    WHOLE     = "whole"
    TABLE     = "table"
    ANNEX     = "annex"
    FIGURE    = "figure"
    NOTE      = "note"
    EXAMPLE   = "example"
    # generic String is allowed
  end

  class BibItemLocality
    # @return [SpecificLocalityType]
    attr_accessor :type

    # @return [LocalizedString]
    attr_accessor :referenceFrom

    # @return [LocalizedString]
    attr_accessor :referenceTo

    # @param type [String]
    # @param referenceFrom [LocalizedString]
    # @param referenceTo [LocalizedString]
    def initialize(type, referenceFrom, referenceTo = nil)
      @type          = type
      @referenceFrom = referenceFrom
      @referenceTo   = referenceTo
    end
  end

  class DocumentRelation
    # @return [DocumentRelationType]
    attr_accessor :type

    attr_accessor :identifier

    # @return [BibliographicItem]
    attr_accessor :bibitem

    # @return [Array<BibItemLocality>]
    attr_accessor :bib_locality

    # @param type [String]
    # @param identifier [String]
    def initialize(type:, identifier: , bib_locality: [])
      @type         = type
      @identifier   = identifier
      @bib_locality = bib_locality
    end
  end

  class DocRelationCollection < Array

    def initialize(relations)
      super relations.map { |r| DocumentRelation.new(r) }
    end

    # @return [Array<DocumentRelation>]
    def replaces
      select { |r| r.type == "replace" }
    end
  end
end