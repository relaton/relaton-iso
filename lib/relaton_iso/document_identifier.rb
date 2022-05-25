module RelatonIso
  class DocumentIdentifier < RelatonBib::DocumentIdentifier
    attr_accessor :all_parts

    def id
      if @all_parts
        if type == "URN"
          return "#{@id.urn}:ser"
            else
          return "#{@id} (all parts)"
        end
      end
      type == "URN" ? @id.urn.to_s : @id.to_s
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
