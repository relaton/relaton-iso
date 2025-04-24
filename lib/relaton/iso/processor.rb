module Relaton
  module Iso
    class Processor < Relaton::Core::Processor
      attr_reader :idtype

      def initialize # rubocop:disable Lint/MissingSuper
        @short = :relaton_iso
        @prefix = "ISO"
        @defaultprefix = %r{^ISO(/IEC)?\s}
        @idtype = "ISO"
        @datasets = %w[iso-ics]
      end

      # @param code [String]
      # @param date [String, nil] year
      # @param opts [Hash]
      # @return [RelatonIsoBib::IsoBibliographicItem]
      def get(code, date, opts)
        require_relative "../iso"
        Bibliography.get(code, date, opts)
      end

      #
      # Fetch all the documents from https://www.iso.org/standards-catalogue/browse-by-ics.html
      #
      # @param [String] source source name (iso-rss, iso-rss-all)
      # @param [Hash] opts
      # @option opts [String] :output directory to output documents
      # @option opts [String] :format output format (xml, yaml, bibxml)
      #
      def fetch_data(_source, opts)
        require_relative "data_fetcher"
        DataFetcher.fetch(**opts)
      end

      # @param xml [String]
      # @return [RelatonIsoBib::IsoBibliographicItem]
      def from_xml(xml)
        require_relative "../iso"
        Item.from_xml xml
      end

      def from_yaml(yaml)
        require_relative "../iso"
        Item.from_yaml yaml
      end

      # @param hash [Hash]
      # @return [RelatonIsoBib::IsoBibliographicItem]
      # def hash_to_bib(hash)
      #   item_hash = HashConverter.hash_to_bib(hash)
      #   ::RelatonIsoBib::IsoBibliographicItem.new(**item_hash)
      # end

      # Returns hash of XML grammar
      # @return [String]
      def grammar_hash
        require "relaton/bib/version"
        require_relative "version"
        Digest::MD5.hexdigest Relaton::Iso::VERSION + Relaton::Bib::VERSION
      end

      # Returns number of workers
      # @return [Integer]
      def threads
        3
      end

      #
      # Remove index file
      #
      def remove_index_file
        require_relative "hit_collection"
        Relaton::Index.find_or_create(:iso, url: true, file: "#{HitCollection::INDEXFILE}.yaml").remove_file
      end
    end
  end
end
