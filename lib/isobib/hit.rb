# require "nokogiri"
# require "net/http"
# require "open-uri"

module Isobib
  class Hit
    DOMAIN = "https://www.iso.org"

    # @return [Isobib::HitCollection]
    attr_reader :hit_collection

    # @return [Array<Hash>]
    attr_reader :hit

    def initialize(hit, hit_collection = nil)
      @hit            = hit
      @hit_collection = hit_collection
    end

    # Parse page.
    # @return [Isobib::IsoBibliographicItem]
    def fetch
      @isobib_item = Scrapper.parse_page @hit unless @isobib_item
      @isobib_item
    end

    def to_s
      inspect
    end

    def inspect
      matchedWords = @hit["_highlightResult"]
        .inject([]) { |a,(_k,v)| a + v["matchedWords"] }.uniq

      "<#{self.class}:#{'0x00%x' % (object_id << 1)} "\
      "@text=\"#{@hit_collection&.hit_pages&.text}\" "\
      "@fullIdentifier=\"#{@isobib_item&.shortref}\" "\
      "@matchedWords=#{matchedWords} "\
      "@category=\"#{@hit["category"]}\" "\
      "@title=\"#{@hit["title"]}\">"
    end
  end
end