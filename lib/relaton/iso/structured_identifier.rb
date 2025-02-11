require_relative "project_number"

module Relaton
  module Iso
    class StructuredIdentifier < Lutaml::Model::Serializable
      attribute :type, :string
      attribute :project_number, ProjectNumber
      attribute :tc_document_number, :integer

      xml do
        root "structuredidentifier"
        map_attribute "type", to: :type
        map_element "project-number", to: :project_number
        map_element "tc-document-number", to: :tc_document_number
      end
    end
  end
end
