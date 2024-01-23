module RelatonIso
  module HashConverter
    include RelatonIsoBib::HashConverter
    extend self

    def create_docid(**args)
      begin
        args[:id] = Pubid::Iso::Identifier.parse args[:id] if args[:id].is_a?(String) && args[:primary]
      rescue StandardError
        warn "Unable to create an Pubid::Iso::Identifier from `#{args[:id]}`"
      end
      DocumentIdentifier.new(**args)
    end
  end
end
