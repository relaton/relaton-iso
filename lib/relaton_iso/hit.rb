# frozen_string_literal: true

module RelatonIso
  # Hit.
  class Hit < RelatonBib::Hit
    # Parse page.
    # @param lang [String, NilClass]
    # @return [RelatonIso::IsoBibliographicItem]
    def fetch(lang = nil)
      @fetch ||= Scrapper.parse_page @hit, lang
    end

    def sort_weight
      case hit["publicationStatus"]
      when "Published" then 0
      when "Under development" then 1
      when "Withdrawn" then 2
      else 3
      end
    end
  end
end
