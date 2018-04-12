# frozen_string_literal: true

module Isobib
  # ISO localized string.
  class IsoLocalizedTitle
    # @return [String]
    attr_reader :title_intro

    # @return [String]
    attr_reader :title_main

    # @return [String]
    attr_reader :title_part

    # @return [String] language code Iso639
    attr_reader :language

    # @return [String] script code Iso15924
    attr_reader :script

    # @param title_intro [String]
    # @param title_main [String]
    # @param title_part [String]
    # @param language [String] language Iso639 code
    # @param script [String] script Iso15924 code
    def initialize(title_intro:, title_main:, title_part:, language:, script:)
      @title_intro = title_intro
      @title_main  = title_main
      @title_part  = title_part
      @language    = language
      @script      = script
    end

    # @return [String]
    def to_s
      "#{@title_intro} -- #{@title_main} -- #{@title_part}"
    end

    def to_xml(builder)
      builder.title(format: 'text/plain', language: language, scrip: script) do
        builder.text to_s
      end
    end
  end
end
