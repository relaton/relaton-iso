require "isobib/localized_string"

module Isobib
  class DocumentStatus

    # @return [LocalizedString]
    attr_accessor :status

    def initialize(status)
      @status = status
    end
  end
end