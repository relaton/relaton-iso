module RelatonIso
  class DocumentIdentifier < RelatonBib::DocumentIdentifier
    def id # rubocop:disable Metrics/MethodLength
      id_str = @id.to_s.sub(/\sED\d+/, "").squeeze(" ").sub(/^ISO\/\s/, "ISO ") # workarounds for pubid gem bugs
      if @all_parts
        if type == "URN"
          return "#{@id.urn}:ser"
        else
          return "#{id_str} (all parts)"
        end
      end
      type == "URN" ? @id.urn.to_s : id_str
    rescue Pubid::Iso::Errors::NoEditionError => e
      Util.warn "WARNING: #{type} identifier can't be generated for #{@id}: #{e.message}"
    end

    def to_h
      @id.to_h.compact
    end

    def remove_part
      @id.part = nil
    end

    def remove_date
      @id.year = nil
    end

    def all_parts
      @all_parts = true
    end
  end
end
