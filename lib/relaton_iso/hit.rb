# frozen_string_literal: true

module RelatonIso
  # Hit.
  class Hit < RelatonBib::Hit
    # @return [RelatonIsoBib::IsoBibliographicItem]
    attr_writer :fetch, :pubid

    # Parse page.
    # @param lang [String, NilClass]
    # @return [RelatonIso::IsoBibliographicItem]
    def fetch(lang = nil, all_parts = false)
      @fetch ||= Scrapper.parse_page @hit, lang, all_parts
    end

    # @return [Integer]
    def sort_weight
      case hit[:status] # && hit["publicationStatus"]["key"]
      when "Published" then 0
      when "Under development" then 1
      when "Withdrawn" then 2
      when "Deleted" then 3
      else 4
      end
    end

    # @return [Pubid::Iso::Identifier]
    def pubid
      Pubid::Iso::Identifier.parse_from_title(hit[:title])
    end
  end
end
