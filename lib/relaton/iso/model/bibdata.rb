require_relative "ext"

module Relaton
  module Iso
    class Bibdata < Item
      model ItemData
      include Bib::BibdataShared
    end
  end
end
