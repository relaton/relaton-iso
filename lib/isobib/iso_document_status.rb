require 'isobib/document_status'

module Isobib
  module IsoDocumentStageCodes
    PREELIMINARY = "00"
    PROPOSAL     = "10"
    PREPARATORY  = "20"
    COMMITTE     = "30"
    ENQUIRY      = "40"
    APPROVAL     = "50"
    PUBLICATION  = "60"
    REVIEW       = "90"
    WITHDRAWAL   = "95"
  end

  module IsoDocumentSubstageCodes
    REGISTRATION              = "00"
    START_OF_MAIN_ACTION      = "20"
    COMPLETION_OF_MAIN_ACTION = "60"
    REPEAT_AN_EARLIER_PHASE   = "92"
    REPEAT_CURRENT_PHASE      = "92"
    ABADON                    = "98"
    PROCEED                   = "99"
  end

  class IsoDocumentStatus < DocumentStatus
    # @return [IsoDocumentStageCodes]
    attr_accessor :stage

    # @return [IsoDocumentSubstageCodes]
    attr_accessor :substage

    def initialize(status, stage, substage)
      super status
      @stage    = stage
      @substage = substage
    end
  end
end