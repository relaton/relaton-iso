require "relaton/processor"

module Relaton
  module RelatonIso
    class Processor < Relaton::Processor
      def initialize
        @short = :relaton_iso
        @prefix = "ISO"
        @defaultprefix = %r{^(ISO)[ /]}
        @idtype = "ISO"
      end

      def get(code, date, opts)
        ::RelatonIso::IsoBibliography.get(code, date, opts)
      end

      def from_xml(xml)
        RelatonIsoBib::XMLParser.from_xml xml
      end
    end
  end
end
