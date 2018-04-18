# frozen_string_literal: true

require 'isoics'
require 'isobib/bibliographic_item'
require 'isobib/iso_document_status'
require 'isobib/iso_localized_title'
require 'isobib/iso_project_group'
require 'isobib/document_relation_collection'

# Add filter method to Array.
class Array
  def filter(type:)
    select { |e| e.type == type }
  end
end

module Isobib
  # Iso document id.
  class IsoDocumentId
    # @return [Integer]
    attr_reader :tc_document_number

    # @return [Integer]
    attr_reader :project_number

    # @return [Integer]
    attr_reader :part_number

    # @param project_number [Integer]
    # @param part_number [Integer]
    def initialize(project_number:, part_number:)
      @project_number = project_number
      @part_number    = part_number
    end

    def to_xml(builder)
      builder.docidentifier(project_number, part: part_number)
    end
  end

  # module IsoDocumentType
  #   INTERNATIONAL_STANDART           = "internationalStandard"
  #   TECHNICAL_SPECIFICATION          = "techinicalSpecification"
  #   TECHNICAL_REPORT                 = "technicalReport"
  #   PUPLICLY_AVAILABLE_SPECIFICATION = "publiclyAvailableSpecification"
  #   INTERNATIONAL_WORKSHOP_AGREEMENT = "internationalWorkshopAgreement"
  # end

  # Iso ICS classificator.
  class Ics < Isoics::ICS
    # @param field [Integer]
    # @param group [Integer]
    # @param subgroup [Integer]
    def initialize(field:, group:, subgroup:)
      super fieldcode: field, groupcode: group, subgroupcode: subgroup
    end
  end

  # Bibliographic item.
  class IsoBibliographicItem < BibliographicItem
    # @return [Isobib::IsoDocumentId]
    attr_reader :docidentifier

    # @return [String]
    attr_reader :edition

    # @!attribute [r] title
    #   @return [Array<Isobib::IsoLocalizedTitle>]

    # @return [Isobib::IsoDocumentType]
    attr_reader :type

    # @return [Isobib::IsoDocumentStatus]
    attr_reader :status

    # @return [Isobib::IsoProjectGroup]
    attr_reader :workgroup

    # @return [Array<Isobib::Ics>]
    attr_reader :ics

    # @param docid [Hash]
    # @param titles [Array<Hash>]
    # @param edition [String]
    # @param language [Array<String>]
    # @param script [Arrra<String>]
    # @param type [String]
    # @param status [Hash]
    # @param workgroup [Hash]
    # @param ics [Array<Hash>]
    # @param dates [Array<Hash>]
    # @param abstract [Array<Hash>]
    # @param contributors [Array<Hash>]
    # @param copyright [Hash]
    # @param source [Array<Hash>]
    # @param relations [Array<Hash>]
    # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
    def initialize(**args)
      super_args = args.select do |k|
        %i[language script dates abstract relations].include? k
      end
      super(super_args)
      @docidentifier = IsoDocumentId.new args[:docid]
      @edition       = args[:edition]
      @title         = args[:titles].map { |t| IsoLocalizedTitle.new(t) }
      @type          = args[:type]
      @status        = IsoDocumentStatus.new(args[:docstatus])
      @workgroup     = IsoProjectGroup.new(args[:workgroup])
      @contributors.unshift ContributionInfo.new(entity: @workgroup,
                                                 role:   ['publisher'])
      @ics = args[:ics].map { |i| Ics.new(i) }
      if args[:copyright]
        @copyright = CopyrightAssociation.new(args[:copyright])
      end
      @source = args[:source].map { |s| TypedUri.new(s) }
    end
    # rubocop:enable Metrics/MethodLength, Metrics/AbcSize

    # Add title to the list of titles.
    # @param iso_localized_title [IsoLocalizedTitle]
    def add_title(iso_localized_title)
      @title << iso_localized_title
    end

    # @param lang [String] language code Iso639
    # @return [IsoLocalizedTitle]
    def title(lang: nil)
      if lang
        @title.find { |t| t.language == lang }
      else
        @title
      end
    end

    # @todo need to add ISO/IEC/IEEE
    # @return [String]
    def shortref
      contributor = @contributors.find do |c|
        c.role.select { |r| r.type == 'publisher' }.any?
      end
      "#{contributor&.entity&.name} #{@docidentifier.project_number}-"\
      "#{@docidentifier.part_number}:#{@copyright.from&.year}"
    end

    # @param type [Symbol] type of url, can be :src/:obp/:rss
    # @return [String]
    def url(type = :src)
      @source.find { |s| s.type == type.to_s }.content.to_s
    end

    # @return [String]
    # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    def to_xml(builder)
      builder.send(:'standard-document', type: type) do
        title.each { |t| t.to_xml builder }
        source.each { |s| s.to_xml builder }
        docidentifier.to_xml builder
        dates.each { |d| d.to_xml builder }
        contributors.each { |c| c.to_xml builder }
        builder.edition edition
        language.each { |l| builder.language l }
        script.each { |s| builder.script s }
        abstract.each { |a| builder.abstract { a.to_xml(builder) } }
        status.to_xml builder
        copyright.to_xml builder
        relations.each { |r| r.to_xml builder }
      end
    end
    # rubocop:enable Metrics/AbcSize, Metrics/MethodLength
  end
end
