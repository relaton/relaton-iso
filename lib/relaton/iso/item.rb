# require_relative "contributor"
require_relative "ext"

module Relaton
  module Iso
    class Item < Bib::Item
      # attributes[:contributor].type = Contributor
      attribute :ext, Ext
    end
  end
end
