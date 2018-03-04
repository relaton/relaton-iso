module Isobib
  class IsoLocalizedTitle
    # @return [String]
    attr_accessor :title_intro

    # @return [String]
    attr_accessor :title_main

    # @return [String]
    attr_accessor :title_part

    # @return [String] language Iso639 code
    attr_accessor :language

    # @return [String] script Iso15924 code
    attr_accessor :script

    def initialize(title_intro, title_main, language, script)
      @title_intro = title_intro
      @title_main  = title_main
      @language    = language
      @scrip       = script
    end
  end
end