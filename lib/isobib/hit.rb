# require "nokogiri"
# require "net/http"
# require "open-uri"

module Isobib
  class Hit
    DOMAIN = "https://www.iso.org"

    def initialize(hit)
      @hit = hit
    end

    # Parse page.
    # @return [Isobib::IsoBibliographicItem]
    def fetch
      @iso_bib_item = Scrapper.parse_page @hit unless @iso_bib_item
      @iso_bib_item
    end
  end
end