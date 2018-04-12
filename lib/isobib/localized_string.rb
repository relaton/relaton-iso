# frozen_string_literal: true

module Isobib
  # Localized string.
  class LocalizedString
    # @return [Array<String>] language Iso639 code
    attr_accessor :language

    # @return [Array<String>] script Iso15924 code
    attr_accessor :script

    # @return [String]
    attr_reader :content

    # @param content [String]
    # @param language [String] language code Iso639
    # @param script [String] script code Iso15924
    def initialize(content, language = nil, script = nil)
      @language = []
      @language << language if language
      @script = []
      @script << script if script
      @content = content
    end

    # @return [String]
    def to_s
      content
    end

    def to_xml(builder)
      builder.parent['language'] = language.join(',') if language.any?
      builder.parent['script']   = script.join(',') if script.any?
      builder.text content
    end
  end
end
