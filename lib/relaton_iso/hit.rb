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

    # @return [Integer]
    def sort_weight
      case hit["publicationStatus"] && hit["publicationStatus"]["key"]
      when "ENT_ACTIVE" then 0
      when "ENT_PROGRESS" then 1
      when "ENT_INACTIVE" then 2
      else 3
      end
    end
  end
end
