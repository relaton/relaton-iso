# frozen_string_literal: true

module Relaton
  module Iso
    # Hit.
    class Hit < Relaton::Core::Hit
      # @return [RelatonIsoBib::IsoBibliographicItem]
      attr_writer :item

      # @return [Pubid::Iso::Identifier] pubid
      attr_writer :pubid

      # Update edition for pubid when provided in Bibliographic Item
      # def update_edition(bibliographic_item)
      #   if bibliographic_item.edition
      #     pubid.root.edition = bibliographic_item.edition.content
      #   end
      # end

      # Parse page.
      # @return [Relaton::Iso::ItemData]
      def item
        @item ||= begin
          url = "#{HitCollection::ENDPOINT}#{hit[:file]}"
          resp = Net::HTTP.get_response URI(url)
          Item.from_yaml resp.body
        end
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
        return @pubid if defined? @pubid

        @pubid = create_pubid hit[:id]
      rescue StandardError
        Util.warn "Unable to create an identifier from #{hit[:id]}"
        @pubid = nil
      end

      private

      def create_pubid(id)
        if id.is_a?(Hash)
          ::Pubid::Iso::Identifier.create(**id)
        else
          id
        end
      end
    end
  end
end
