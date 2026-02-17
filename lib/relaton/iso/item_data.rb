module Relaton
  module Iso
    class ItemData < Bib::ItemData
      def create_id(without_date: false)
        docid = docidentifier.find(&:primary) || docidentifier.first
        return unless docid

        if docid.content.is_a?(String)
          create_id_from_string(docid.content, without_date)
        else
          create_id_from_pubid(docid.content, without_date)
        end
      end

      private

      def create_id_from_string(content, without_date)
        pubid = without_date ? content.sub(/:\d{4}$/, "") : content
        self.id = pubid.gsub(/\W+/, "")
      end

      def create_id_from_pubid(content, without_date)
        pubid = without_date ? content.exclude(:year) : content
        self.id = pubid.to_s(with_prf: true).gsub(/\W+/, "")
      end

      def create_relation(**args)
        Relation.new(**args)
      end
    end
  end
end
