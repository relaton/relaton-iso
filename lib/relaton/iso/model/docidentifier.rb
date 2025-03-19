module Relaton
  module Iso
    class Pubid < Lutaml::Model::Type::Value
      class << self
        def cast(value)
          value.is_a?(String) ? ::Pubid::Iso::Identifier.parse(value) : value
        rescue ::Pubid::Core::Errors::ParseError
          value
        end
      end

      ::Lutaml::Model::Config::AVAILABLE_FORMATS.each do |format|
        define_method(:"to_#{format}") do
          to_s
        end
      end

      def urn
        value.urn
      end
    end

    class Docidentifier < Bib::Docidentifier
      attribute :content, Pubid

      def to_s # rubocop:disable Metrics/AbcSize
        case type
        when "URN" then @all_parts ? "#{content.urn}:ser" : content.urn.to_s
        when "iso-reference"
          params = content.value.to_h.reject { |k, _| k == :typed_stage }
          ::Pubid::Iso::Identifier.create(language: "en", **params).to_s(format: :ref_num_short)
        else
          @all_parts ? "#{content} (all parts)" : content.to_s
        end
      end

      def remove_part
        content.part = nil
      end

      def to_all_parts
        remove_part
        remove_date
        @all_parts = true
      end

      def remove_date
        content.year = nil
      end
    end
  end
end
