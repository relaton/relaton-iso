require "isobib/formatted_string"
require "isobib/contribution_info"
require "isobib/bibliographic_date"

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
    STANDARD     = 'standard'
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

  class CopyrightAssociation

    # @return [DateTime]
    attr_reader :from

    # @return [DateTime]
    attr_reader :to

    # @return [Contributor]
    attr_reader :owner

    # @param owner [Hash] contributor
    # @param from [String] date
    # @param to [String] date
    def initialize(owner:, from:, to: nil)
      @owner = Organization.new(owner)
      @from  = DateTime.strptime(from, "%Y") unless from.empty?
      @to    = DateTime.parse(to) if to
    end
  end

  class TypedUri
    # @return [Symbol] :src/:obp/:rss
    attr_reader :type
    # @retutn [URI]
    attr_reader :content

    # @param type [String] src/obp/rss
    # @param content [String]
    def initialize(type:, content:)
      @type    = type
      @content = URI content if content
    end
  end

  class BibliographicItem

    # @return [Array<FormattedString>]
    attr_accessor :title

    # @return [Array<TypedUri>]
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

    # @!attribute [r] abstract
    #   @return [Arra<FormattedString>]

    # @return [DocumentStatus]
    attr_accessor :status

    # @return [CopyrightAssociation]
    attr_accessor :copyright

    # @return [DocRelationCollection]
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

    # @param docid [DocumentIdentifier]
    def add_docidentifier(docid)
      @docidentifier << docid
    end

    # @param lang [String] language code Iso639
    # @return [FormattedString, Array<FormattedString>]
    def abstract(lang: nil)
      if lang
        @abstract.find { |a| a.language.include? lang }
      else
        @abstract
      end
    end

    # def add_contributor(contributor)
    #   @contributors << contributor
    # end
  end
end