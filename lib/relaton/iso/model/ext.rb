require_relative "doctype"
require_relative "stagename"
require_relative "structured_identifier"

module Relaton
  module Iso
    class Ext < Bib::Ext
      attribute :schema_version, method: :get_schema_version
      attribute :doctype, Doctype
      attribute :structuredidentifier, StructuredIdentifier
      attribute :horizontal, :boolean
      attribute :stagename, Stagename
      attribute :updates_document_type, :string, values: Doctype::TYPES
      attribute :fast_track, :boolean
      attribute :price_code, :string

      def get_schema_version
        Relaton.schema_versions["relaton-model-iso"]
      end

      xml do
        root "ext"
        map_element "horizontal", to: :horizontal
        map_element "stagename", to: :stagename
        map_element "updates-document-type", to: :updates_document_type
        map_element "fast-track", to: :fast_track
        map_element "price-code", to: :price_code
      end
    end
  end
end
