module RelatonIso
  class DocumentIdentifier < RelatonBib::DocumentIdentifier
    def id
      id_str = @id.to_s.sub(/\sED\d+/, "")
      if @all_parts
        if type == "URN"
          return "#{@id.urn}:ser"
        else
          return "#{id_str} (all parts)"
        end
      end
      type == "URN" ? @id.urn.to_s : id_str
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
