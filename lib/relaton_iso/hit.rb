# frozen_string_literal: true

module RelatonIso
  # Hit.
  class Hit < RelatonBib::Hit
    # @return [RelatonIsoBib::IsoBibliographicItem]
    attr_writer :fetch, :pubid

    # Update edition for pubid when provided in Bibliographic Item
    def update_edition(bibliographic_item)
      if bibliographic_item.edition
        # add edition to base document if available
        if pubid.base
          pubid.base.edition = bibliographic_item.edition.content
        else
          pubid.edition = bibliographic_item.edition.content
        end
      end
    end

    # Parse page.
    # @param lang [String, nil]
    # @return [RelatonIso::IsoBibliographicItem]
    def fetch(lang = nil)
      @fetch ||= Scrapper.parse_page self, lang
      # update edition for pubid using fetched data
      update_edition(@fetch)
      @fetch
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
      @pubid ||= Pubid::Iso::Identifier.parse_from_title(hit[:title])
    end
  end
end
