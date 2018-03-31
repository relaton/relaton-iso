# require "nokogiri"
# require "net/http"
# require "open-uri"
require "isobib/iso_bibliographic_item"

module Isobib
  class Hit
    DOMAIN = "https://www.iso.org"

    def initialize(hit)
      @hit = hit
    end

    # Parse page.
    # @return [Hash]
    def fetch
      Scrapper.parse_page @hit
    end
  end
end