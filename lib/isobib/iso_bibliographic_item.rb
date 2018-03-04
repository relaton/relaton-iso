require "isobib/bibliographic_item"
require "isobib/iso_document_status"
require "isobib/iso_localized_title"
require "isobib/iso_project_group"

module Isobib

  class IsoDocumentId
    # @return [Integer]
    attr_accessor :ts_document_number

    # @return [Integer]
    attr_accessor :project_number

    # @return [Integer]
    attr_accessor :part_number
  end

  module IsoDocumentType
    INTERNATIONAL_STANDART           = "internationalStandard"
    TECHNICAL_SPECIFICATION          = "techinicalSpecification"
    TECHNICAL_REPORT                 = "technicalReport"
    PUPLICLY_AVAILABLE_SPECIFICATION = "publiclyAvailableSpecification"
    INTERNATIONAL_WORKSHOP_AGREEMENT = "internationalWorkshopAgreement"
  end

  class Ics
    # @return [Integer]
    attr_accessor :field

    # @return [Integer]
    attr_accessor :group

    # @return [Integer]
    attr_accessor :subgroup
  end

  class IsoBibliographicItem < BibliographicItem
    # @return [IsoDocumentId]
    attr_accessor :docidentifier

    # @return [Array<IsoLocalizedTitle>]
    attr_accessor :title

    # @return [IsoDocumentType]
    attr_accessor :type

    # @return [IsoDocumentStatus]
    attr_accessor :status

    # @return [IsoProjectRoup]
    attr_accessor :workgroup

    # @return [Ics]
    attr_accessor :ics

    def initialize(docidentifier, title, type, status, workgroup, ics)
      @docidentifier = docidentifier
      @title         = [title]
      @type          = type
      @stattus       = status
      @workgroup     = workgroup
      @ics           = ics
    end
  end
end