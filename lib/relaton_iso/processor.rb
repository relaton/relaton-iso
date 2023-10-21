require "relaton/processor"

module RelatonIso
  class Processor < Relaton::Processor
    attr_reader :idtype

    def initialize # rubocop:disable Lint/MissingSuper
      @short = :relaton_iso
      @prefix = "ISO"
      @defaultprefix = %r{^ISO(/IEC)?\s}
      @idtype = "ISO"
    end

    # @param code [String]
    # @param date [String, NilClass] year
    # @param opts [Hash]
    # @return [RelatonIsoBib::IsoBibliographicItem]
    def get(code, date, opts)
      ::RelatonIso::IsoBibliography.get(code, date, opts)
    end

    # @param xml [String]
    # @return [RelatonIsoBib::IsoBibliographicItem]
    def from_xml(xml)
      ::RelatonIsoBib::XMLParser.from_xml xml
    end

    # @param hash [Hash]
    # @return [RelatonIsoBib::IsoBibliographicItem]
    def hash_to_bib(hash)
      item_hash = ::RelatonIsoBib::HashConverter.hash_to_bib(hash)
      ::RelatonIsoBib::IsoBibliographicItem.new(**item_hash)
    end

    # Returns hash of XML grammar
    # @return [String]
    def grammar_hash
      @grammar_hash ||= ::RelatonIsoBib.grammar_hash
    end

    # Returns number of workers
    # @return [Integer]
    def threads
      3
    end
  end
end
