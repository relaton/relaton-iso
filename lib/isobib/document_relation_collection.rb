# frozen_string_literal: true

module Isobib
  # module DocumentRelationType
  #   PARENT        = 'parent'
  #   CHILD         = 'child'
  #   OBSOLETES     = 'obsoletes'
  #   UPDATES       = 'updates'
  #   COMPLEMENTS   = 'complements'
  #   DERIVED_FORM  = 'derivedForm'
  #   ADOPTED_FORM  = 'adoptedForm'
  #   EQUIVALENT    = 'equivalent'
  #   IDENTICAL     = 'identical'
  #   NONEQUIVALENT = 'nonequivalent'
  # end

  # class SpecificLocalityType
  #   SECTION   = 'section'
  #   CLAUSE    = 'clause'
  #   PART      = 'part'
  #   PARAGRAPH = 'paragraph'
  #   CHAPTER   = 'chapter'
  #   PAGE      = 'page'
  #   WHOLE     = 'whole'
  #   TABLE     = 'table'
  #   ANNEX     = 'annex'
  #   FIGURE    = 'figure'
  #   NOTE      = 'note'
  #   EXAMPLE   = 'example'
  #   # generic String is allowed
  # end

  # Bibliographic item locality.
  class BibItemLocality
    # @return [Isobib::SpecificLocalityType]
    attr_reader :type

    # @return [Isobib::LocalizedString]
    attr_reader :reference_from

    # @return [Isobib::LocalizedString]
    attr_reader :reference_to

    # @param type [String]
    # @param referenceFrom [Isobib::LocalizedString]
    # @param referenceTo [Isobib::LocalizedString]
    def initialize(type, reference_from, reference_to = nil)
      @type           = type
      @reference_from = reference_from
      @reference_to   = reference_to
    end
  end

  # Documett relation
  class DocumentRelation
    # @return [String]
    attr_reader :type

    # @return [String]
    attr_reader :identifier, :url

    # @return [Isobib::BibliographicItem]
    attr_reader :bibitem

    # @return [Array<Isobib::BibItemLocality>]
    attr_reader :bib_locality

    # @param type [String]
    # @param identifier [String]
    def initialize(type:, identifier:, url:, bib_locality: [])
      @type         = type
      @identifier   = identifier
      @url          = url
      @bib_locality = bib_locality
    end

    def to_xml(builder)
      builder.relation(type: type) do
        builder.bibitem do
          builder.formattedref identifier
          builder.docidentifier identifier
        end
        # builder.url url
      end
    end
  end

  # Document relations collection
  class DocRelationCollection < Array
    def initialize(relations)
      super relations.map { |r| DocumentRelation.new(r) }
    end

    # @return [Array<Isobib::DocumentRelation>]
    def replaces
      select { |r| r.type == 'replace' }
    end
  end
end
