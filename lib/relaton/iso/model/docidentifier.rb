module Relaton
  module Iso
    class Docidentifier < Bib::Docidentifier
      attribute :content, :string

      attr_reader :pubid

      def initialize(arg = nil, **kwargs)
        arg.is_a?(Hash) ? super(arg) : super(**kwargs)
        # Content may have been set before type during lutaml init. Re-run
        # the setter so type-dependent parsing (e.g. iso-tc bypass) applies.
        raw = arg.is_a?(Hash) ? (arg["content"] || arg[:content]) : kwargs[:content]
        self.content = raw if raw
      end

      alias_method :original_content=, :content=
      alias_method :original_content, :content

      def content=(value)
        @pubid = nil
        @raw_content = nil

        if type == "iso-tc" && value.is_a?(String)
          @raw_content = value
        else
          parsed =
            case value
            when ::Pubid::Iso::Identifier::Base then value
            when String
              begin
                ::Pubid::Iso::Identifier.parse(value)
              rescue StandardError
                Util.warn "Failed to parse Pubid: #{value}"
                nil
              end
            end

          if parsed
            @pubid = parsed
          elsif value.is_a?(String)
            @raw_content = value
          end
        end

        send(:original_content=, to_s)
      end

      def content
        return @raw_content if @raw_content
        return render_pubid(@pubid) if @pubid

        original_content
      end

      def to_s
        content.to_s
      end

      def to_all_parts!
        return unless @pubid

        remove_part!
        remove_date!
        remove_stage!
        @pubid.all_parts = true
        refresh_content!
      end

      def remove_stage!
        remove_attr!(:stage)
      end

      def remove_part!
        remove_attr!(:part)
      end

      def remove_date!
        remove_attr!(:year)
      end

      def exclude_year
        return @raw_content if @raw_content
        return nil unless @pubid

        pubid = @pubid.exclude(:year)
        current = pubid
        while current.base
          current.base = current.base.exclude(:year)
          current = current.base
        end
        pubid
      end

      private

      def render_pubid(pubid)
        case type
        when "URN" then pubid.urn
        when "iso-reference", "iso-with-lang"
          pubid.to_s(format: :ref_num_short, with_prf: true)
        else
          pubid.to_s(with_prf: true)
        end
      end

      def remove_attr!(attr)
        return unless @pubid

        @pubid.send("#{attr}=", nil)
        base = @pubid.base
        while base
          base.send("#{attr}=", nil)
          base = base.base
        end
        refresh_content!
      end

      def refresh_content!
        send(:original_content=, to_s)
      end
    end
  end
end
