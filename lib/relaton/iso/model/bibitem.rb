module Relaton
  module Iso
    class Bibitem < Item
      model ItemData
      include Bib::BibitemShared
    end
  end
end
