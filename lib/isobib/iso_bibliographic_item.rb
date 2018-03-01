require 'iso_document_id'
require 'iso_document_type'

module Isobib
  class IsoDocumentId
    attr_accessor :ts_document_number, :project_number, :part_number,
      :iso_bibliographic_item
  end

  module IsoDocumentType
    INTERNATIONAL_STANDART           = "internationalStandard"
    TECHNICAL_SPECIFICATION          = "techinicalSpecification"
    TECHNICAL_REPORT                 = "technicalReport"
    PUPLICLY_AVAILABLE_SPECIFICATION = "publiclyAvailableSpecification"
    INTERNATIONAL_WORKSHOP_AGREEMENT = "internationalWorkshopAgreement"
  end

  class Ics
    attr_accessor :field, :group, :subgroup, :iso_bibliographic_item
  end

  class IsoBibliographicItem
    attr_accessor :docidentifier, :title, :type, :status, :workgroup, :ics

    # docidentifier - IsoDocumentId
    # title - IsoLocalizedTitle
    # type - IsoDocumentType
    # status - IsoDocumentStatus
    # workgroup - IsoProjectWorkgroup
    # ics - Ics
    def initialize(docidentifier, title, type, status, workgroup, ics)
      @docidentifier = docidentifier
      docidentifier.iso_bibliographic_item = self
      @title         = [title]
      title.iso_bibliographic_item = self
      @type          = type
      @stattus       = status
      status.iso_bibliographic_item = self
      @workgroup     = workgroup
      workgroup.iso_bibliographic_item = self
      @ics           = ics
      ics.iso_bibliographic_item = self
    end
  end
end