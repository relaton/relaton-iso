module Relaton
  module Iso
    class Pubid < Lutaml::Model::Type::Value
      module Renderer
      end

      class << self
        def cast(value)
          value.is_a?(String) ? ::Pubid::Iso::Identifier.parse(value) : value
        rescue StandardError
          Util.warn "Failed to parse Pubid: #{value}"
          value
        end
      end

      ::Lutaml::Model::Config::AVAILABLE_FORMATS.each do |format|
        define_method(:"to_#{format}") { value.to_s with_prf: true }
      end

      def to_h = value.to_h
      def urn = value.urn
    end

    class Docidentifier < Bib::Docidentifier
      include Pubid::Renderer

      attribute :content, Pubid

      def content_to_xml(model, parent, doc)
        doc.add_xml_fragment parent, model.to_s
      end

      def content_to_key_value(model, doc)
        doc["content"] = model.to_s
      end

      def to_all_parts!
        if content.is_a? String
          Util.warn "Cannot convert String to all parts: #{content}"
          return
        end

        remove_part!
        remove_date!
        remove_stage!
        content.all_parts = true
      end

      def remove_stage!
        remove_attr! :stage
        # return if content.is_a? String

        # content.stage = nil
        # base = content.base
        # while base
        #   base.stage = nil
        #   base = base.base
        # end
      end

      def remove_part!
        remove_attr! :part
        # return if content.is_a? String

        # content.part = nil
        # base = content.base
        # while base
        #   base.part = nil
        #   base = base.base
        # end
      end

      def remove_date!
        remove_attr! :year
        # return if content.is_a? String

        # content.year = nil
        # base = content.base
        # while base
        #   base.year = nil
        #   base = base.base
        # end
      end

      def exclude_year
        pubid = content.exclude(:year)
        current_pubid = pubid
        while current_pubid.base
          current_pubid.base = current_pubid.base.exclude(:year)
          current_pubid = current_pubid.base
        end
        pubid
      end

      def to_s
        return content if content.is_a? String

        case type
        when "URN" then content.urn
        when "iso-reference" then iso_reference
        else content.to_s with_prf: true
        end
      end

      def iso_reference
        return content.to_s(format: :ref_num_short, with_prf: true) if content.language

        pubid_dup = content.dup
        pubid_dup.language = "en"
        pubid_dup.to_s(format: :ref_num_short, with_prf: true)
      end

      private

      def remove_attr!(attr)
        return false if content.is_a? String

        content.send("#{attr}=", nil)
        base = content.base
        while base
          base.send("#{attr}=", nil)
          base = base.base
        end
        true
      end
    end
  end
end
