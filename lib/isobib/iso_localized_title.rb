module Isobib
  class IsoLocalizedTitle
    attr_accessor :title_intro, :title_main, :title_part, :language, :script,
      :iso_bibliographic_item

    def initialize(title_intro:, title_main:, language:, script:)
      @title_intro = title_intro
      @title_main  = title_main
      @language    = language
      @scrip       = script
    end
  end
end