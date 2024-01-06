module RelatonIso
  module HashConverter
    include RelatonIsoBib::HashConverter
    extend self

    def create_docid(**args)
      args[:id] = Pubid::Iso::Identifier.parse args[:id] if args[:id].is_a?(String) && args[:id] != "ISO/IEC DIR"
      DocumentIdentifier.new(**args)
    end
  end
end
