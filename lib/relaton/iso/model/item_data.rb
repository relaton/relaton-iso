module Relaton
  module Iso
    class ItemData < Bib::ItemData
      def deep_clone
        Item.from_yaml Item.to_yaml(self)
      end

      def create_relation(**args)
        Relation.new(**args)
      end
    end
  end
end
