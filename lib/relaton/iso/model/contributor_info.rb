module Relaton
  module Iso
    class ContributorInfo < Lutaml::Model::Serializable
      choice do
        attribute :person, Bib::Person
      end
    end
  end
end
