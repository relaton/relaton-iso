module Relaton
  module Iso
    class ItemData < Bib::ItemData
      def create_id(without_date: false)
        docid = docidentifier.find(&:primary) || docidentifier.first
        return unless docid

        pubid = without_date ? docid.content.exclude(:year) : docid.content
        self.id = pubid.to_s(with_prf: true).gsub(/\W+/, "")
      end

      def create_relation(**args)
        Relation.new(**args)
      end

      def to_xml(bibdata: false, **opts)
        add_notes opts[:note] do
          bibdata ? Bibdata.to_xml(self) : Bibitem.to_xml(self)
        end
      end

      def to_yaml(**opts)
        add_notes opts[:note] do
          Item.to_yaml(self)
        end
      end

      def to_json(**opts)
        add_notes opts[:note] do
          Item.to_json(self)
        end
      end

      # private

      # def add_notes(notes)
      #   self.note ||= []
      #   Relaton.array(notes).each { |nt| note << Bib::Note.new(**nt) }
      #   result = yield
      #   Relaton.array(notes).each { note.pop }
      #   result
      # end
    end
  end
end
