require "relaton/bib/hash_parser_v1"
require_relative "../iso"

module Relaton
  module Iso
    #
    # This module is used to parse hash data from Relaton YAML version 1 files.
    # It needs for trasition form Relaton v! to Relaton v2.
    #
    module HashParserV1
      include Bib::HashParserV1
      extend self

      PUBLISHERS = {
        "IEC" => "International Electrotechnical Commission",
        "ISO" => "International Organization for Standardization",
        "IEEE" => "Institute of Electrical and Electronics Engineers",
        "SAE" => "SAE International",
        "CIE" => " International Commission on Illumination",
        "ASME" => "American Society of Mechanical Engineers",
      }.freeze

      private

      def ext_hash_to_bib(ret) # rubocop:disable Metrics/AbcSize,Metrics/CyclomaticComplexity,Metrics/MethodLength,Metrics/PerceivedComplexity
        ret[:ext] ||= {}
        ret[:ext][:schema_version] = ret[:ext].delete(:"schema-version")
        doctype_hash_to_bib ret
        ret[:ext][:subdoctype] = ret.delete(:subdoctype) if ret[:subdoctype]
        ret[:ext][:flavor] ||= flavor(ret)
        ret[:ext][:horizontal] = ret.delete(:horizontal) unless ret[:horizontal].nil?
        editorialgroup_hash_to_bib ret
        approvalgroup_hash_to_bib ret
        ics_hash_to_bib ret
        structuredidentifier_hash_to_bib ret
        stagename_hash_to_bib ret
        ret[:ext][:fast_track] = ret.delete(:fast_track) unless ret[:fast_track].nil?
        ret[:ext][:price_code] = ret.delete(:price_code) if ret[:price_code]
        ret[:ext] = Ext.new(**ret[:ext]) if ret[:ext]
      end

      def create_docid(**args)
        Docidentifier.new(**args)
      end

      #
      # Ovverides superclass's method
      #
      # @param item [Hash]
      # @retirn [RelatonIsoBib::IsoBibliographicItem]
      def bib_item(item)
        ItemData.new(**item)
      end

      #
      # Ovverides superclass's method
      #
      # @param title [Hash]
      # @return [RelatonBib::TypedTitleString]
      def typed_title_strig(title)
        Relaton::Bib::Title.new(**title)
      end

      # @param ret [Hash]
      def editorialgroup_hash_to_bib(ret) # rubocop:disable Metrics/AbcSize,Metrics/MethodLength
        eg = ret.dig(:ext, :editorialgroup) || ret[:editorialgroup]
        return unless eg

        ret[:ext]&.delete(:editorialgroup)
        ret.delete(:editorialgroup)
        ret[:contributor] ||= []
        add_group_contributors(ret, eg, "committee")
      end

      def approvalgroup_hash_to_bib(ret) # rubocop:disable Metrics/AbcSize
        ag = ret.dig(:ext, :approvalgroup) || ret[:approvalgroup]
        return unless ag

        ret[:ext]&.delete(:approvalgroup)
        ret.delete(:approvalgroup)
        ret[:contributor] ||= []
        add_group_contributors(ret, ag, "authorizer", role_type: "authorizer")
      end

      def add_group_contributors(ret, group, description, role_type: "author") # rubocop:disable Metrics/AbcSize,Metrics/CyclomaticComplexity,Metrics/MethodLength,Metrics/PerceivedComplexity
        subdiv_types = {
          technical_committee: "technical-committee",
          subcommittee: "subcommittee",
          workgroup: "workgroup",
        }
        subdiv_types.each do |key, subdiv_type|
          array(group[key]).each do |wg|
            wg[:content] ||= wg.delete(:name)
            next unless wg[:content]

            prefix = wg[:prefix] || wg[:identifier]&.split("/")&.first || extract_prefix(wg[:content])
            publisher_name = PUBLISHERS[prefix]
            name = if publisher_name
                     [Bib::TypedLocalizedString.new(content: publisher_name)]
                   elsif prefix
                     [Bib::TypedLocalizedString.new(content: prefix)]
                   else
                     [Bib::TypedLocalizedString.new(content: wg[:content])]
                   end
            abbreviation = prefix ? Bib::LocalizedString.new(content: prefix) : nil

            subdivision = Bib::Subdivision.new(
              type: subdiv_type, subtype: wg[:type],
              name: [Bib::TypedLocalizedString.new(content: wg[:content])],
              identifier: wg[:identifier] ? [Bib::OrganizationType::Identifier.new(content: wg[:identifier])] : [],
            )

            role = Bib::Contributor::Role.new(
              type: role_type,
              description: [Bib::LocalizedMarkedUpString.new(content: description)],
            )

            ret[:contributor] << Bib::Contributor.new(
              role: [role],
              organization: Bib::Organization.new(
                name: name, subdivision: [subdivision], abbreviation: abbreviation,
              ),
            )
          end
        end
      end

      def extract_prefix(content)
        match = content&.match(%r{^([A-Z]+)/})
        match[1] if match
      end

      # @param ret [Hash]
      def structuredidentifier_hash_to_bib(ret)
        struct_id = ret.dig(:ext, :structuredidentifier) || ret[:structuredidentifier]
        return unless struct_id

        struct_id[:project_number] = project_number_hash_to_bib(struct_id)
        ret[:ext][:structuredidentifier] = StructuredIdentifier.new(**struct_id)
      end

      def project_number_hash_to_bib(struct_id)
        ProjectNumber.new(
          part: struct_id.delete(:part),
          subpart: struct_id.delete(:subpart),
          amendment: struct_id.delete(:amendment),
          corrigendum: struct_id.delete(:corrigendum),
          origyr: struct_id.delete(:origyr),
          content: struct_id.delete(:project_number),
        )
      end

      def stagename_hash_to_bib(ret)
        stagename = ret.dig(:ext, :stagename) || ret[:stagename]
        return unless stagename

        ret[:ext][:stagename] = Stagename.new(**stagename_args(stagename))
      end

      def stagename_args(stagename)
        if stagename.is_a? Hash
          stagename
        else
          { content: stagename }
        end
      end

      def create_doctype(args)
        Doctype.new(**args)
      end

      def create_relation(rel)
        Relation.new(**rel)
      end
    end
  end
end
