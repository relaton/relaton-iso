# frozen_string_literal: true

# require 'isobib/iso_bibliographic_item'
require 'isobib/scrapper'
require 'isobib/hit_pages'

module Isobib
  # Class methods for search ISO standards.
  class IsoBibliography
    class << self
      # @param text [String]
      # @return [Isobib::HitPages]
      def search(text)
        HitPages.new text
      end

      # @param text [String]
      # @return [Array<IsoBibliographicItem>]
      def search_and_fetch(text)
        Scrapper.get(text)
      end
    end
  end
end
