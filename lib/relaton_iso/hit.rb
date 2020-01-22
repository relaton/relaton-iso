# frozen_string_literal: true

module RelatonIso
  # Hit.
  class Hit < RelatonBib::Hit
    # @return [RelatonIso::HitCollection]
    attr_reader :hit_collection

    # Parse page.
    # @param lang [String, NilClass]
    # @return [RelatonIso::IsoBibliographicItem]
    def fetch(lang = nil)
      @fetch ||= Scrapper.parse_page @hit, lang
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

    def sort_weight
      case hit["publicationStatus"]
      when "Published" then 0
      when "Under development" then 1
      when "Withdrawn" then 2
      else
        3
      end
    end
  end
end
