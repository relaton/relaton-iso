module Relaton
  module Iso
    class Doctype < Bib::Doctype
      VALUES = %w[
        international-standard technical-specification technical-report publicly-available-specification
        international-workshop-agreement guide recommendation amendment technical-corrigendum directive
        committee-document addendum
      ].freeze

      attribute :content, :string, values: VALUES
    end
  end
end
