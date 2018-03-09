require "isobib/localized_string"

module Isobib
  module StringFormat
    PLAIN    = 'plain'
    HTML     = 'html'
    DOCBOOK  = 'docbook'
    TEI      = 'tei'
    ASCIIDOC = 'asciidoc'
    MARKDOWN = 'markdown'
    ISODOC   = 'isodoc'
  end

  class FormattedString < LocalizedString
    # @return [StringFormat]
    attr_accessor :type

    # @param content [String]
    # @param type [StringFormat] the format type, default plain.
    def initialize(content:, language:, script:, type: StringFormat::PLAIN)
      super(content, language, script)
      @type = type
    end
  end
end