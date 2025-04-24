module Relaton
  module Iso
    class Stagename < Lutaml::Model::Serializable
      attribute :abbreviation, :string
      attribute :content, :string

      xml do
        root "stagename"
        map_attribute "abbreviation", to: :abbreviation
        map_content to: :content
      end
    end
  end
end
