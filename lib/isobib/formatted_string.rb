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

    # @param type [StringFormat] the format type, default plain.
    def initialize(type = StringFormat::PLAIN)
      super
      @type = type
    end
  end
end