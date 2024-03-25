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
      Util.warn "#{type} identifier can't be generated for `#{@id}`: #{e.message}"
    end

    def to_h
      stringify_values(@id.to_h) if @id.respond_to? :to_h
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

    def stringify_values(hash)
      hash.transform_values { |v| stringify(v) }.reject { |_k, v| v.empty? }
    end

    def stringify(val)
      case val
      when Array then val.map { |i| i.is_a?(Hash) ? stringify_values(i) : i.to_s }
      when Hash then stringify_values(val)
      when Symbol then val
      else val.to_s
      end
    end
  end
end
