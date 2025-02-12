module Relaton
  module Iso
    class Bibitem < Item
      model Bib::ItemData

      # we don't need ext element in bibitem XML output
      mappings[:xml].instance_variable_get(:@elements).delete("ext")

      mappings[:xml].instance_eval do
        root "bibitem"
      end
    end
  end
end
