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
      hit[:title].split.reverse.inject(hit[:title]) do |acc, part|
        return Pubid::Iso::Identifier.parse(acc)
      rescue Pubid::Iso::Errors::ParseError
        # delete parts from the title until it's parseable
        acc.reverse.sub(part.reverse, "").reverse.strip
      end
    end
  end
end
