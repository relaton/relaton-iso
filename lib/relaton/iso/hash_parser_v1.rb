require "relaton/bib/hash_parser_v1"
require_relative "../iso"

module Relaton
  module Iso
    #
    # This module is used to parse hash data from Relaton YAML version 1 files.
    # It needs for trasition form Relaton v! to Relaton v2.
    #
    module HashParserV1
      include Core::ArrayWrapper
      include Bib::HashParserV1
      extend self

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
      def editorialgroup_hash_to_bib(ret)
        eg = ret.dig(:ext, :editorialgroup) || ret[:editorialgroup]
        return unless eg

        ret[:ext][:editorialgroup] = create_iso_project_group(eg)
      end

      def approvalgroup_hash_to_bib(ret)
        ag = ret.dig(:ext, :approvalgroup) || ret[:approvalgroup]
        return unless ag

        ret[:ext][:approvalgroup] = create_iso_project_group(ag)
      end

      def create_iso_project_group(args)
        args[:technical_committee] = workgroup_hash_to_bib args[:technical_committee]
        args[:subcommittee] = workgroup_hash_to_bib args[:subcommittee]
        args[:workgroup] = workgroup_hash_to_bib args[:workgroup]
        ISOProjectGroup.new(**args)
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
