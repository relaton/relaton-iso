module Relaton
  module Iso
    class ProjectNumber < Lutaml::Model::Serializable
      attribute :part, :integer
      attribute :subpart, :integer
      attribute :amendment, :integer
      attribute :corrigendum, :integer
      attribute :origyr, :string
      attribute :content, :string

      xml do
        root "project-number"
        map_attribute "part", to: :part
        map_attribute "subpart", to: :subpart
        map_attribute "amendment", to: :amendment
        map_attribute "corrigendum", to: :corrigendum
        map_attribute "origyr", to: :origyr
        map_content to: :content
      end
    end
  end
end
