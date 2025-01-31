module Relaton
  module Iso
    class IsoWorkgroup < Lutaml::Model::Serializable
      attribute :number, :integer
      attribute :type, :string
      attribute :identifier, :string
      attribute :prefix, :string
      attribute :content, :string

      xml do
        map_attribute "number", to: :number
        map_attribute "type", to: :type
        map_attribute "identifier", to: :identifier
        map_attribute "prefix", to: :prefix
        map_content to: :content
      end
    end
  end
end
