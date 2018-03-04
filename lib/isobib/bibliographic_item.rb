module Isobib
  module BibItemType
    ARTICLE      = 'article'
    BOOK         = 'book'
    BOOKLET      = 'booklet'
    CONFERENCE   = 'conference'
    MANUAL       = 'manual'
    PROCEEDINGS  = 'proceedings'
    PRESENTATION = 'presentation'
    THESIS       = 'thesis'
    TECHREPORT   = 'techreport'
    STANDARD     = 'standsrd'
    UNPUBLISHED  = 'unpublished'
  end

  class DocumentIdentifier

    # @return [String]
    attr_accessor :id

    # @return [String]
    attr_accessor :type

    def initialize(id)
      @id = id
    end
  end

  class CopyrightAccociation

    # @return [DateTime]
    attr_accessor :from

    # @return [DateTime]
    attr_accessor :to

    # @return [Contributor]
    attr_accessor :owner

    def initialize(from, owner)
      @from  = from
      @owner = owner
    end
  end

  class BibliographicItem

    # @return [Array<FormattedString>]
    attr_accessor :title

    # @return [URI]
    attr_accessor :source

    # @return [BibItemType]
    attr_accessor :type

    # @return [Array<DocumentIdentifier>]
    attr_accessor :docidentifier

    # @return [Array<BibliographicDate>]
    attr_accessor :dates

    # @return [Array<ContributionInfo>]
    attr_accessor :contributors

    # @return [String]
    attr_accessor :edition

    # @return [Array<FormattedString>]
    attr_accessor :notes

    # @return [Array<String>] language Iso639 code
    attr_accessor :language

    # @return [Array<String>] script Iso15924 code
    attr_accessor :script

    # @return [FormattedString]
    attr_accessor :formatted_ref

    # @return [Arra<FormattedString>]
    attr_accessor :abstract

    # @return [DocumentStatus]
    attr_accessor :status

    # @return [CopyrightAssociation]
    attr_accessor :copyright

    # @return [Array<DocumentRelation>]
    attr_accessor :relations

    def initialize
      @title         = []
      @docidentifier = []
      @dates         = []
      @contributors  = []
      @notes         = []
      @language      = []
      @script        = []
      @abstract      = []
      @relations     = []
    end

    def add_docidentifier(docid)
      @docidentifier << docid
    end

    # def add_contributor(contributor)
    #   @contributors << contributor
    # end
  end
end