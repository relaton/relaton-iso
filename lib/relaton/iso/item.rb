# require_relative "contributor"
require_relative "ext"

module Relaton
  module Iso
    class Item < Bib::Item
      model Bib::ItemData

      attribute :ext, Ext
    end
  end
end
