module Relaton
  module Iso
    class Doctype < Bib::Doctype
      TYPES = %w[
        international-standard technical-specification technical-report publicly-available-specification
        international-workshop-agreement guide recommendation amendment technical-corrigendum directive
        committee-document addendum
      ].freeze

      attribute :content, :string, values: TYPES
    end
  end
end
