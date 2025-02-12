require_relative "ext"

module Relaton
  module Iso
    class Bibdata < Item
      model Bib::ItemData

      attribute :ext, Ext

      # we don't need id attribute in bibdata XML output
      mappings[:xml].instance_variable_get(:@attributes).delete("id")

      mappings[:xml].instance_eval do
        root "bibdata"
      end
    end
  end
end
