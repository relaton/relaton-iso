# frozen_string_literal: true

require 'isobib/localized_string'

module Isobib
  # Dovument status.
  class DocumentStatus
    # @return [Isobib::LocalizedString]
    attr_reader :status

    # @param status [Isobib::LocalizedString]
    def initialize(status)
      @status = status
    end

    def to_xml(builder)
      builder.status do
        # FormattedString.instance_method(:to_xml).bind(status).call builder
        status.to_xml builder
      end
    end
  end
end
