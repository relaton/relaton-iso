# encoding: utf-8
require "isobib/iso_bibliographic_item"
require "isobib/scrapper"

module Isobib
  class IsoBibliography
    @@iso_bibliographic_items = []

    class << self

      # @param text [String]
      # @return [Array<IsoBibliographicItem>]
      def search(text)
        @@iso_bibliographic_items = Scrapper.get(text).map do |item|
          begin
            IsoBibliographicItem.new item
          rescue => e
            require "pry-byebug"; binding.pry
            e
          end
        end
      end
    end
  end
end