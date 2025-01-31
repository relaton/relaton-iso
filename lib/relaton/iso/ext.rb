require_relative "doctype"
require_relative "iso_project_group"
require_relative "stagename"


module Relaton
  module Iso
    class Ext < Lutaml::Model::Serializable
      attribute :schema_version, :string
      attribute :doctype, Doctype
      attribute :subdoctype, :string
      attribute :flavor, :string
      attribute :horizontal, :boolean
      attribute :editorialgroup, ISOProjectGroup
      attribute :approvalgroup, ISOProjectGroup
      attribute :ics, Bib::ICS, collection: true
      attribute :structuredidentifier, Bib::StructuredIdentifier, collection: true
      attribute :stagename, Stagename
      attribute :updates_document_type, Doctype
      attribute :fast_track, :boolean
      attribute :price_code, :string

      xml do
        root "ext"
        map_attribute "schema-version", to: :schema_version
        map_element "doctype", to: :doctype
        map_element "subdoctype", to: :subdoctype
        map_element "flavor", to: :flavor
        map_element "horizontal", to: :horizontal
        map_element "editorialgroup", to: :editorialgroup
        map_element "approvalgroup", to: :approvalgroup
        map_element "ics", to: :ics
        map_element "structuredidentifier", to: :structuredidentifier
        map_element "stagename", to: :stagename
        map_element "updates-document-type", to: :updates_document_type
        map_element "fast-track", to: :fast_track
        map_element "price-code", to: :price_code
      end
    end
  end
end
