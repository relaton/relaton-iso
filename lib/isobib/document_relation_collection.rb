# frozen_string_literal: true

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
    SECTION   = 'section'
    CLAUSE    = 'clause'
    PART      = 'part'
    PARAGRAPH = 'paragraph'
    CHAPTER   = 'chapter'
    PAGE      = 'page'
    WHOLE     = 'whole'
    TABLE     = 'table'
    ANNEX     = 'annex'
    FIGURE    = 'figure'
    NOTE      = 'note'
    EXAMPLE   = 'example'
    # generic String is allowed
  end

  # Bibliographic item locality.
  class BibItemLocality
    # @return [SpecificLocalityType]
    attr_reader :type

    # @return [LocalizedString]
    attr_reader :reference_from

    # @return [LocalizedString]
    attr_reader :reference_to

    # @param type [String]
    # @param referenceFrom [LocalizedString]
    # @param referenceTo [LocalizedString]
    def initialize(type, reference_from, reference_to = nil)
      @type           = type
      @reference_from = reference_from
      @reference_to   = reference_to
    end
  end

  # Documett relation
  class DocumentRelation
    # @return [DocumentRelationType]
    attr_reader :type

    attr_reader :identifier

    # @return [BibliographicItem]
    attr_reader :bibitem

    # @return [Array<BibItemLocality>]
    attr_reader :bib_locality

    # @param type [String]
    # @param identifier [String]
    def initialize(type:, identifier:, bib_locality: [])
      @type         = type
      @identifier   = identifier
      @bib_locality = bib_locality
    end
  end

  # Document relations collection
  class DocRelationCollection < Array
    def initialize(relations)
      super relations.map { |r| DocumentRelation.new(r) }
    end

    # @return [Array<DocumentRelation>]
    def replaces
      select { |r| r.type == 'replace' }
    end
  end
end
