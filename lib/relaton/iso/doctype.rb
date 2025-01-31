module Relaton
  module Iso
    class Doctype < Lutaml::Model::Serializable
      attribute :abbreviation, :string
      attribute :content, :string, values: %w[
        international-standard technical-specification technical-report publicly-available-specification
        international-workshop-agreement guide recommendation amendment technical-corrigendum directive
        committee-document addendum
      ]

      xml do
        root "doctype"
        map_attribute "abbreviation", to: :abbreviation
        map_content to: :content
      end
    end
  end
end
