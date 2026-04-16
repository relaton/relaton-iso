require_relative "docidentifier"

module Relaton
  module Iso
    class ItemBase < Lutaml::Model::Serializable
      include Bib::NamespaceHelper

      attr_accessor :type

      model ItemData

      instance_exec(&Bib::ItemShared::ATTRIBUTES)
      attribute :docidentifier, Docidentifier, collection: true, initialize_empty: true
      attribute :relation, Relation, collection: true, initialize_empty: true

      xml do
        map_attribute "type", to: :type
        instance_exec(&Bib::ItemShared::XML_BODY)
      end
    end
  end
end
