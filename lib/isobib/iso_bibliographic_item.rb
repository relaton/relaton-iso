require "isoics"
require "isobib/bibliographic_item"
require "isobib/iso_document_status"
require "isobib/iso_localized_title"
require "isobib/iso_project_group"
require "isobib/document_relation_collection"

class Array
  def filter(type:)
    select { |e| e.type == type }
  end
end

module Isobib

  class IsoDocumentId
    # @return [Integer]
    attr_accessor :ts_document_number

    # @return [Integer]
    attr_accessor :project_number

    # @return [Integer]
    attr_accessor :part_number

    # @param project_number [Integer]
    # @param part_number [Integer]
    def initialize(project_number:, part_number:)
      @project_number = project_number
      @part_number    = part_number
    end
  end

  module IsoDocumentType
    INTERNATIONAL_STANDART           = "internationalStandard"
    TECHNICAL_SPECIFICATION          = "techinicalSpecification"
    TECHNICAL_REPORT                 = "technicalReport"
    PUPLICLY_AVAILABLE_SPECIFICATION = "publiclyAvailableSpecification"
    INTERNATIONAL_WORKSHOP_AGREEMENT = "internationalWorkshopAgreement"
  end

  class Ics < Isoics::ICS
    # # @return [Integer]
    # attr_accessor :field

    # # @return [Integer]
    # attr_accessor :group

    # # @return [Integer]
    # attr_accessor :subgroup

    # @param field [Integer]
    # @param group [Integer]
    # @param subgroup [Integer]
    def initialize(field:, group:, subgroup:)
      super fieldcode: field, groupcode: group, subgroupcode: subgroup
      # @field    = field
      # @group    = group
      # @subgroup = subgroup
    end
  end

  class IsoBibliographicItem < BibliographicItem
    # @return [IsoDocumentId]
    attr_reader :docidentifier

    # @!attribute [r] title
    #   @return [Array<IsoLocalizedTitle>]

    # @return [IsoDocumentType]
    attr_reader :type

    # @return [IsoDocumentStatus]
    attr_reader :status

    # @return [IsoProjectGroup]
    attr_reader :workgroup

    # @return [BibliographicIcs]
    attr_reader :ics

    # @param docid [Hash]
    # @param titles [Array<Hash>]
    # @param type [String]
    # @param status [Hash]
    # @param workgroup [Hash]
    # @param ics [Hash]
    # @param dates [Array<Hash>]
    # @param abstract [Array<Hash>]
    # @param contributors [Array<Hash>]
    # @param copyright [Hash]
    # @param source [Array<Hash>]
    # @param relations [Array<Hash>]
    def initialize(docid:, edition: nil, titles:, type:, docstatus:, workgroup:,
        ics:, dates: [], abstract: [], contributors: [], copyright: nil, source: [],
        relations: [])
      super()
      @docidentifier = IsoDocumentId.new docid
      @edition       = edition
      @title         = titles.map { |t| IsoLocalizedTitle.new(t) }
      @type          = type
      @status        = IsoDocumentStatus.new(docstatus)
      @workgroup     = IsoProjectGroup.new(workgroup)
      @contributors << ContributionInfo.new(entity: @workgroup)
      @ics           = Ics.new(ics)
      @dates         = dates.map { |d| BibliographicDate.new(d) }
      @abstract      = abstract.map { |a| FormattedString.new(a) }
      @contributors  += contributors.map do |c|
        ContributionInfo.new(entity: Organization.new(c[:entity]), role: c[:role])
      end
      @copyright     = CopyrightAssociation.new(copyright) if copyright
      @source        = source.map { |s| TypedUri.new(s) }
      @relations     = DocRelationCollection.new(relations)
    end

    # Add title to the list of titles.
    # @param t [IsoLocalizedTitle]
    def add_title(t)
      @title << t
    end

    # @param lang [String] language code Iso639
    # @return [IsoLocalizedTitle]
    def title(lang: nil)
      if lang
        @title.find { |t| t.language == lang}
      else
        @title
      end
    end

    # @todo need to add ISO/IEC/IEEE
    # @return [String]
    def shortref
      contributor = @contributors.find do |c|
        c.role.select { |r| r.type == ContributorRoleTypes::PUBLISHER }.any?
      end

      "#{contributor&.entity&.name} #{@docidentifier.project_number}-#{@docidentifier.part_number}:#{@copyright.from.year}"
    end
    
    # @param type [Symbol] type of url, can be :src/:obp/:rss
    # @return [String]
    def url(type = :src)
      @source.find { |s| s.type == type.to_s }.content.to_s
    end
  end
end