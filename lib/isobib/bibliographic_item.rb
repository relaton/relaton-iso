# frozen_string_literal: true

require 'isobib/formatted_string'
require 'isobib/contribution_info'
require 'isobib/bibliographic_date'

module Isobib
  # module BibItemType
  #   ARTICLE      = 'article'
  #   BOOK         = 'book'
  #   BOOKLET      = 'booklet'
  #   CONFERENCE   = 'conference'
  #   MANUAL       = 'manual'
  #   PROCEEDINGS  = 'proceedings'
  #   PRESENTATION = 'presentation'
  #   THESIS       = 'thesis'
  #   TECHREPORT   = 'techreport'
  #   STANDARD     = 'standard'
  #   UNPUBLISHED  = 'unpublished'
  # end

  # Document identifier.
  class DocumentIdentifier
    # @return [String]
    attr_reader :id

    # @return [String]
    attr_reader :type

    def initialize(id)
      @id = id
    end
  end

  # Copyright association.
  class CopyrightAssociation
    # @return [Time]
    attr_reader :from

    # @return [Time]
    attr_reader :to

    # @return [Isobib::ContributionInfo]
    attr_reader :owner

    # @param owner [Hash] contributor
    # @param from [String] date
    # @param to [String] date
    def initialize(owner:, from:, to: nil)
      @owner = ContributionInfo.new entity: Organization.new(owner)
      @from  = Time.strptime(from, '%Y') unless from.empty?
      @to    = Time.parse(to) if to
    end

    def to_xml(builder)
      builder.copyright do
        builder.from from.year
        builder.to to.year if to
        owner.to_xml builder
      end
    end
  end

  # Typed URI
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

    def to_xml(builder)
      builder.source(content.to_s, type: type)
    end
  end

  # Bibliographic item
  class BibliographicItem
    # @return [Array<Isobib::FormattedString>]
    attr_reader :title

    # @return [Array<Isobib::TypedUri>]
    attr_reader :source

    # @return [Isobib::BibItemType]
    attr_reader :type

    # @return [Array<Isobib::DocumentIdentifier>]
    attr_reader :docidentifier

    # @return [Array<Isobib::BibliographicDate>]
    attr_reader :dates

    # @return [Array<Isobib::ContributionInfo>]
    attr_reader :contributors

    # @return [String]
    attr_reader :edition

    # @return [Array<Isobib::FormattedString>]
    attr_reader :notes

    # @return [Array<String>] language Iso639 code
    attr_reader :language

    # @return [Array<String>] script Iso15924 code
    attr_reader :script

    # @return [Isobib::FormattedString]
    attr_reader :formatted_ref

    # @!attribute [r] abstract
    #   @return [Arra<FormattedString>]

    # @return [Isobib::DocumentStatus]
    attr_reader :status

    # @return [Isobib::CopyrightAssociation]
    attr_reader :copyright

    # @return [Isobib::DocRelationCollection]
    attr_reader :relations

    # @param language [Arra<String>]
    # @param script [Array<String>]
    # @param dates [Array<Hash>]
    # @param contributors [Array<Hash>]
    # @param abstract [Array<Hash>]
    # @param relations [Array<Hash>]
    # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
    def initialize(**args)
      @title         = []
      @docidentifier = []
      @dates         = (args[:dates] || []).map { |d| BibliographicDate.new(d) }
      @contributors  = (args[:contributors] || []).map do |c|
        ContributionInfo.new(entity: Organization.new(c[:entity]),
                             role:   c[:role])
      end
      @notes         = []
      @language      = args[:language]
      @script        = args[:script]
      @abstract      = (args[:abstract] || []).map do |a|
        FormattedString.new(a)
      end
      @relations = DocRelationCollection.new(args[:relations] || [])
    end
    # rubocop:enable Metrics/MethodLength, Metrics/AbcSize

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
  end
end
