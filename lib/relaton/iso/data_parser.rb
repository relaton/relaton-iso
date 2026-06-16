# frozen_string_literal: true

require "nokogiri"
require_relative "../iso"
require_relative "scraper"

module Relaton
  module Iso
    #
    # Parses one ISO Open Data record (`iso_deliverables_metadata.jsonl` line)
    # into an `Relaton::Iso::ItemData`.
    #
    # See https://www.iso.org/open-data.html for the field reference.
    #
    class DataParser
      ATTRS = %i[
        type docidentifier docnumber edition language script title status ics
        date contributor abstract copyright source relation place
        structuredidentifier ext
      ].freeze

      DOCTYPES = {
        "IS" => "international-standard",
        "TS" => "technical-specification",
        "TR" => "technical-report",
        "PAS" => "publicly-available-specification",
        "GUIDE" => "guide",
        "IWA" => "international-workshop-agreement",
        "R" => "recommendation",
        "ISP" => "international-standard",
        "DATA" => "international-standard",
        "TTA" => "international-standard",
      }.freeze

      SUPPLEMENT_DOCTYPES = {
        "Amd" => "amendment",
        "Cor" => "technical-corrigendum",
        "Add" => "addendum",
        "Suppl" => "supplement",
      }.freeze

      DOC_URL = "https://www.iso.org/standard/%d.html"
      OBP_URL = "https://www.iso.org/obp/ui/en/#!iso:std:%d:en"
      RSS_URL = "https://www.iso.org/contents/data/standard/%s/%s/%d.detail.rss"

      #
      # @param [Hash] pub one Open Data record
      # @param [Hash{Integer=>String}] ref_index map of Open Data `id` ->
      #   `reference`, used to resolve `replaces` / `replacedBy` (which are
      #   numeric IDs in the source).
      # @param [Hash] errors error accumulator (`Hash.new(true)`); fields are
      #   AND-ed across all records by the `report_errors` machinery.
      # @param [Hash{String=>Hash}] tc_index map of TC/SC reference ->
      #   `{ "en" => title, "fr" => title }`, used to resolve the human
      #   committee label from the Open Data technical-committees dataset.
      # @param [Hash{String=>Array<String>}] amend_index map of base
      #   reference -> list of supplement (Amd/Cor/Add) references that
      #   target it. Open Data records the supplement -> base direction only
      #   via the reference string, so we pre-build the reverse map.
      # @param [Hash{String=>String}] date_index map of reference ->
      #   `publicationDate`, used to attach a `published` date to each
      #   emitted relation's bibitem when the related document is itself
      #   present in the Open Data feed.
      #
      def initialize(pub, ref_index = {}, errors = {}, tc_index = {}, amend_index = {}, date_index = {})
        @pub = pub
        @ref_index = ref_index
        @errors = errors
        @tc_index = tc_index
        @amend_index = amend_index
        @date_index = date_index
      end

      def parse
        ItemData.new(**ATTRS.each_with_object({}) { |a, h| h[a] = send(a) })
      end

      private

      def type = "standard"

      # ---- identifiers -----------------------------------------------------

      def reference
        @reference ||= @pub["reference"] || ""
      end

      def pubid
        return @pubid if defined?(@pubid)

        @pubid = begin
          ::Pubid::Iso::Identifier.parse(reference)
        rescue StandardError => e
          Util.warn "Failed to parse pubid `#{reference}`: #{e.message}"
          nil
        end
      end

      def docidentifier
        ids = []
        if pubid
          ids << Docidentifier.new(content: pubid, type: "ISO", primary: true)
          if (ref = iso_reference_pubid)
            ids << Docidentifier.new(content: ref, type: "iso-reference")
          end
          if (urn = safe_urn_docid)
            ids << urn
          end
        else
          ids << Docidentifier.new(content: reference, type: "ISO", primary: true)
        end
        @errors[:docidentifier] &&= ids.empty?
        ids
      end

      def safe_urn_docid
        return nil unless urn_pubid

        Docidentifier.new(content: urn_pubid, type: "URN")
      rescue StandardError
        nil
      end

      def iso_reference_pubid
        params = pubid.to_h.except(:typed_stage)
        ::Pubid::Iso::Identifier.create(language: "en", **params)
      rescue StandardError
        nil
      end

      def urn_pubid
        return @urn_pubid if defined?(@urn_pubid)

        @urn_pubid = begin
          dup_pubid = pubid.dup
          if dup_pubid.respond_to?(:stage=) && stage_dotted &&
             dup_pubid.respond_to?(:stage) && dup_pubid.stage.nil?
            dup_pubid.stage = ::Pubid::Iso::Identifier.parse_stage(stage_dotted)
          end
          dup_pubid
        rescue StandardError
          nil
        end
      end

      def docnumber
        pubid&.to_s&.match(/\d+/)&.to_s
      end

      def edition
        return nil unless @pub["edition"]

        Bib::Edition.new(content: @pub["edition"].to_s)
      end

      # ---- language / script ----------------------------------------------

      def language
        langs = Array(@pub["languages"]).dup
        langs << "en" if langs.empty?
        langs.uniq
      end

      def script
        language.filter_map { |l| script_for(l) }.uniq
      end

      def script_for(lang)
        case lang
        when "en", "fr" then "Latn"
        when "ru" then "Cyrl"
        end
      end

      # ---- title -----------------------------------------------------------

      def title
        result = []
        result += titles_for("en")
        result += titles_for("fr")
        @errors[:title] &&= result.empty?
        result
      end

      def titles_for(lang)
        raw = @pub.dig("title", lang)
        return [] if raw.nil? || raw.empty?

        Bib::Title.from_string(normalize_dashes(raw), lang, script_for(lang))
      end

      def normalize_dashes(str)
        str.gsub(/\s—\s/, " - ").gsub(/\s–\s/, " - ")
      end

      # ---- status ----------------------------------------------------------

      # Open Data exposes a 4-digit stage code (e.g. 2098 = 20.98, 6060 = 60.60).
      # Records occasionally come through with 2 or 3 digits (zero-padded).
      def stage_dotted
        return @stage_dotted if defined?(@stage_dotted)

        @stage_dotted =
          if @pub["currentStage"]
            digits = format("%04d", @pub["currentStage"].to_i)
            "#{digits[0, 2]}.#{digits[2, 2]}"
          end
      end

      def status
        return nil unless stage_dotted

        stg, sub = stage_dotted.split(".")
        Bib::Status.new(
          stage: Bib::Status::Stage.new(content: stg),
          substage: sub ? Bib::Status::Stage.new(content: sub) : nil,
        )
      end

      # ---- ICS -------------------------------------------------------------

      def ics
        return [] unless @pub["icsCode"]

        Array(@pub["icsCode"]).map do |code|
          info = safe_isoics_fetch(code)
          Bib::ICS.new(code: code, text: info&.description)
        end
      end

      def safe_isoics_fetch(code)
        Isoics.fetch code
      rescue StandardError
        nil
      end

      # ---- dates -----------------------------------------------------------

      def date
        pd = @pub["publicationDate"]
        return [] if pd.nil? || pd.empty?

        [Bib::Date.new(type: "published", at: pd)]
      end

      # ---- contributors ----------------------------------------------------

      def contributor
        publishers + Array(editorialgroup_contributor)
      end

      def publishers
        reference.sub(/\s.*/, "").split("/").filter_map do |abbrev|
          info = Scraper::PUBLISHERS[abbrev]
          next unless info

          name = Bib::TypedLocalizedString.new(content: info[:name])
          abbr = Bib::LocalizedString.new(content: abbrev)
          uri = Bib::Uri.new(content: info[:uri]) if info[:uri]
          org = Bib::Organization.new(name: [name], abbreviation: abbr, uri: [uri].compact)
          role = Bib::Contributor::Role.new(type: "publisher")
          Bib::Contributor.new(organization: org, role: [role])
        end
      end

      def editorialgroup_contributor
        wg = @pub["ownerCommittee"]
        return nil if wg.nil? || wg.empty?

        parts = wg.split("/")
        prefix = parts[0]
        type = parts[1]&.match(/^[A-Z]+/)&.to_s || "TC"

        publisher = Scraper::PUBLISHERS[prefix]
        name = if publisher
                 [Bib::TypedLocalizedString.new(content: publisher[:name])]
               elsif prefix
                 [Bib::TypedLocalizedString.new(content: prefix)]
               else
                 []
               end
        abbreviation = (Bib::LocalizedString.new(content: prefix) if prefix)

        label = @tc_index.dig(wg, "en") || wg
        subdivision = Bib::Subdivision.new(
          type: "technical-committee",
          subtype: type,
          name: [Bib::TypedLocalizedString.new(content: label)],
          identifier: [Bib::OrganizationType::Identifier.new(content: wg)],
        )

        role = Bib::Contributor::Role.new(
          type: "author",
          description: [Bib::LocalizedMarkedUpString.new(content: "committee")],
        )

        Bib::Contributor.new(
          role: [role],
          organization: Bib::Organization.new(
            name: name, subdivision: [subdivision], abbreviation: abbreviation,
          ),
        )
      end

      # ---- abstract --------------------------------------------------------

      def abstract
        %w[en fr].filter_map do |lang|
          html = @pub.dig("scope", lang)
          next if html.nil? || html.empty?

          text = strip_html(html)
          next if text.empty?

          Bib::Abstract.new(content: text, language: lang, script: script_for(lang))
        end
      end

      def strip_html(html)
        Nokogiri::HTML.fragment(html).text.strip.gsub(/\s+/, " ")
      end

      # ---- copyright -------------------------------------------------------

      def copyright
        from = reference[/(?<=:)\d{4}/] ||
               @pub["publicationDate"]&.match(/\d{4}/)&.to_s
        return [] unless from && !from.empty?

        owner_name = reference.match(/.*?(?=\s)/).to_s
        name = Bib::TypedLocalizedString.new(content: owner_name)
        org = Bib::Organization.new(name: [name])
        contrib = Bib::ContributionInfo.new(organization: org)
        [Bib::Copyright.new(owner: [contrib], from: from)]
      end

      # ---- source links ----------------------------------------------------

      def source
        id = @pub["id"]
        return [] unless id

        pad = format("%06d", id)
        [
          Bib::Uri.new(type: "src", content: format(DOC_URL, id)),
          Bib::Uri.new(type: "obp", content: format(OBP_URL, id)),
          Bib::Uri.new(type: "rss", content: format(RSS_URL, pad[0, 2], pad[2, 2], id)),
        ]
      end

      # ---- relations -------------------------------------------------------

      # Open Data semantics:
      #   * `replaces`   - older docs THIS one supersedes -> `obsoletes`
      #   * `replacedBy` - newer docs that supersede THIS one -> `obsoletedBy`
      # Amendments/corrigenda/addenda are stitched in via two routes:
      #   * on the BASE record, look up `@amend_index` for supplements
      #     targeting it (-> `updatedBy`); the index is pre-built in
      #     `DataFetcher#build_ref_index` because Open Data only records
      #     the supplement -> base direction via the reference string.
      #   * on the SUPPLEMENT record itself, derive the base from
      #     `pubid.base` and emit the forward `updates` relation.
      def relation
        rels = []
        rels += build_relations(@pub["replaces"], "obsoletes")
        rels += build_relations(@pub["replacedBy"], "obsoletedBy")
        rels += amendment_relations
        rels += base_relation
        rels
      end

      def build_relations(ids, type)
        Array(ids).filter_map do |id|
          ref = @ref_index[id] || @ref_index[id.to_s]
          next unless ref

          relation_for(ref, type)
        end
      end

      def amendment_relations
        Array(@amend_index[pubid&.to_s || reference]).map do |amend_ref|
          relation_for(amend_ref, "updatedBy")
        end
      end

      def base_relation
        return [] unless pubid&.respond_to?(:base) && pubid.base

        [relation_for(pubid.base.to_s, "updates")]
      end

      def relation_for(ref, type)
        docid = Docidentifier.new(content: ref, type: "ISO", primary: true)
        attrs = {
          docidentifier: [docid],
          formattedref: Bib::Formattedref.new(content: ref),
        }
        if (pub_date = @date_index[ref]) && !pub_date.empty?
          attrs[:date] = [Bib::Date.new(type: "published", at: pub_date)]
        end
        Relation.new(type: type, bibitem: ItemData.new(**attrs))
      end

      # ---- structured identifier ------------------------------------------

      def structuredidentifier
        return nil unless @pub["id"]

        pnum = ProjectNumber.new(content: @pub["id"].to_s)
        publisher = pubid&.respond_to?(:publisher) ? pubid.publisher : nil
        StructuredIdentifier.new(project_number: pnum, type: publisher || "ISO")
      end

      # ---- place -----------------------------------------------------------

      def place
        [Bib::Place.new(city: "Geneva")]
      end

      # ---- ext -------------------------------------------------------------

      def ext
        Ext.new(
          doctype: doctype,
          flavor: "iso",
          ics: ics,
          structuredidentifier: structuredidentifier,
          stagename: nil,
          updates_document_type: nil,
          fast_track: nil,
          price_code: nil,
        )
      end

      def doctype
        type = SUPPLEMENT_DOCTYPES[@pub["supplementType"]] ||
               DOCTYPES[@pub["deliverableType"]] ||
               "international-standard"
        Doctype.new(content: type)
      end
    end
  end
end
