# require_relative "contributor"
require_relative "docidentifier"
require_relative "ext"

module Relaton
  module Iso
    class Relation < Bib::Relation
    end

    class Item < Bib::Item
      model ItemData

      attribute :docidentifier, Docidentifier, collection: true
      attribute :relation, Relation, collection: true
      attribute :ext, Ext
    end
  end
end
