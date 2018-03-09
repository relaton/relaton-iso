module Isobib
  class IsoLocalizedTitle
    # @return [String]
    attr_accessor :title_intro

    # @return [String]
    attr_accessor :title_main

    # @return [String]
    attr_accessor :title_part

    # @return [String] language code Iso639
    attr_accessor :language

    # @return [String] script code Iso15924
    attr_accessor :script

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
      @scrip       = script
    end

    # @return [String]
    def to_s
      "#{@title_intro} -- #{@title_main} -- #{@title_part}"
    end
  end
end