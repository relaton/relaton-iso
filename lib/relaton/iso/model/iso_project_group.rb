module Relaton
  module Iso
    class ISOProjectGroup < Lutaml::Model::Serializable
      attribute :agency, :string, collection: true
      attribute :technical_committee, Bib::WorkGroup, collection: true
      attribute :subcommittee, Bib::WorkGroup, collection: true
      attribute :workgroup, Bib::WorkGroup, collection: true
      attribute :secretariat, :string

      xml do
        root "editorialgroup"

        map_element "agency", to: :agency
        map_element "technical-committee", to: :technical_committee
        map_element "subcommittee", to: :subcommittee
        map_element "workgroup", to: :workgroup
        map_element "secretariat", to: :secretariat
      end
    end
  end
end
