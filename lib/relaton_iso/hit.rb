# frozen_string_literal: true

module RelatonIso
  # Hit.
  class Hit
    # @return [RelatonIso::HitCollection]
    attr_reader :hit_collection

    # @return [Array<Hash>]
    attr_reader :hit

    # @param hit [Hash]
    # @param hit_collection [RelatonIso:HitCollection]
    def initialize(hit, hit_collection = nil)
      @hit            = hit
      @hit_collection = hit_collection
    end

    # Parse page.
    # @return [RelatonIso::IsoBibliographicItem]
    def fetch
      @fetch ||= Scrapper.parse_page @hit
    end

    # @return [String]
    def to_s
      inspect
    end

    # @return [String]
    def inspect
      matched_words = @hit["_highlightResult"].
        reduce([]) { |a, (_k, v)| a + v["matchedWords"] }.uniq

      "<#{self.class}:#{format('%#.14x', object_id << 1)} "\
      "@text=\"#{@hit_collection&.hit_pages&.text}\" "\
      "@fullIdentifier=\"#{@fetch&.shortref}\" "\
      "@matchedWords=#{matched_words} "\
      "@category=\"#{@hit['category']}\" "\
      "@title=\"#{@hit['title']}\">"
    end

    # @param builder [Nokogiri::XML::Builder]
    def to_xml(builder = nil, **opts)
      if builder
        fetch.to_xml builder, **opts
      else
        builder = Nokogiri::XML::Builder.new(encoding: "UTF-8") do |xml|
          fetch.to_xml xml, **opts
        end
        builder.doc.root.to_xml
      end
    end
  end
end
