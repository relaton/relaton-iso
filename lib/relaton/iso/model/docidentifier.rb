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

      xml do
        root "docidentifier"
      end

      # iso-tc identifiers are TC document numbers, not ISO standard
      # identifiers — parsing them through Pubid adds a spurious
      # "ISO" prefix (#178). Bypass Pubid casting for iso-tc content
      # in both direct construction and XML deserialization paths.
      def initialize(arg = nil, **kwargs)
        if arg.is_a?(Hash)
          raw_content = arg["content"] if arg["type"] == "iso-tc"
          super(arg)
        else
          raw_content = kwargs[:content] if kwargs[:type] == "iso-tc"
          super(**kwargs)
        end
        @content = raw_content if raw_content.is_a?(String)
      end

      # Bypass Pubid casting for iso-tc content (#178).
      # The lutaml-model setter is defined via define_method, so we
      # wrap it with alias_method instead of super.
      alias_method :original_content=, :content=
      def content=(value)
        if value.is_a?(String) && type == "iso-tc"
          @iso_tc_raw = value
          @content = value
          return
        end
        send(:original_content=, value)
      end

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
      end

      def remove_part!
        remove_attr! :part
      end

      def remove_date!
        remove_attr! :year
      end

      def exclude_year
        return content if content.is_a? String

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
        return @iso_tc_raw if @iso_tc_raw

        case type
        when "URN" then content.urn
        when "iso-reference", "iso-with-lang" then iso_reference
        else content.to_s with_prf: true
        end
      end

      def iso_reference
        content.to_s(format: :ref_num_short, with_prf: true)

        # return content.to_s(format: :ref_num_short, with_prf: true) if content.language

        # pubid_dup = content.dup
        # pubid_dup.language = "en"
        # pubid_dup.to_s(format: :ref_num_short, with_prf: true)
      end

      private

      def remove_attr!(attr)
        return if content.is_a? String

        content.send("#{attr}=", nil)
        base = content.base
        while base
          base.send("#{attr}=", nil)
          base = base.base
        end
      end
    end
  end
end
