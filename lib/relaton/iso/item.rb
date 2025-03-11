# require_relative "contributor"
require_relative "ext"

module Relaton
  module Iso
    class Relation < Bib::Relation
    end

    class Item < Bib::Item
      model Bib::ItemData

      attribute :relation, Relation, collection: true
      attribute :ext, Ext
    end
  end
end
