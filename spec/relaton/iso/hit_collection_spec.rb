describe Relaton::Iso::HitCollection do
  let(:hit1) do
    Relaton::Iso::Hit.new({ id: { publisher: "ISO", number: "19115", part: "1", year: "2014" } })
  end

  let(:hit2) do
    Relaton::Iso::Hit.new({ id: { publisher: "ISO", number: "19115", part: "2", year: "2015" } })
  end

  let(:ref) { ::Pubid::Iso::Identifier.create publisher: "ISO", number: "19115", part: "1", year: "2014" }
  subject { described_class.new ref }

  describe "#ref_pubid_no_year" do
    it "returns pubid without year" do
      expect(subject.ref_pubid_no_year.to_s).to eq "ISO 19115-1"
    end
  end

  describe "#ref_pubid_excluded" do
    it "returns pubid with excluded parts" do
      expect(subject.ref_pubid_excluded.to_s).to eq "ISO 19115-1"
    end
  end

  describe "#find" do
    let(:index) do
      idx = Relaton::Index::Type.new :iso
      idx.instance_variable_set :@index, [
        { id: { publisher: "ISO", number: "19115", part: "1", year: "2014" } },
        { id: { publisher: "ISO", number: "19115", part: "2", year: "2015" } },
        { id: { publisher: "ISO", number: "19115", part: "3", year: "2016" } },
        { id: "ISO 19115-1:2014" },
      ]
      idx
    end

    before { expect(subject).to receive(:index).and_return index }

    it "find both Hash & String index rows" do
      expect(subject.find).to be_a described_class
      expect(subject.size).to eq 2
      expect(subject.first).to be_a Relaton::Iso::Hit
    end

    it "fing all parts & reverse sort by pubid" do
      ref.all_parts = true
      expect(subject.find.size).to eq 3
      expect(subject.first.pubid.to_s).to eq "ISO 19115-3:2016"
    end
  end

  describe "#pubid_match?" do
    it "exclude year" do
      expect(subject.pubid_match?(publisher: "ISO", number: "19115", part: "1")).to be true
    end

    it "exclude edition" do
      expect(subject.pubid_match?(publisher: "ISO", number: "19115", part: "1", edition: "2")).to be true
    end
  end

  context "#create_pubid" do
    it "rescues from error" do
      expect do
        subject.create_pubid publisher: "ISO", stage: "ST", number: "19115"
      end.to output(
        /\[relaton-iso\] WARN: \(ISO 19115-1:2014\) cannot parse typed stage or stage 'ST/,
      ).to_stderr_from_any_process
    end
  end

  describe "#excludings" do
    it "returns excluded parts" do
      expect(subject.excludings).to eq %i[year stage iteration]
    end

    it "returns excluded parts with all_parts" do
      ref.all_parts = true
      expect(subject.excludings).to eq %i[year part stage iteration]
    end

    it "returns excluded parts when ref has no part" do
      subject.instance_variable_set :@ref, ::Pubid::Iso::Identifier.create(publisher: "ISO", number: "19115")
      expect(subject.excludings).to eq %i[year part stage iteration]
    end
  end

  it "#index" do
    expect(subject.index).to be_a Relaton::Index::Type
  end

  describe "#fetch_doc" do
    it "no all_parts" do
      subject.instance_variable_set :@array, [hit1, hit2]
      expect(hit1).to receive(:item).and_return :doc
      expect(subject.fetch_doc).to be :doc
    end

    it "all_parts" do
      ref.all_parts = true
      subject.instance_variable_set :@array, [hit1, hit2]
      expect(subject).to receive(:to_all_parts).and_return :doc
      expect(subject.fetch_doc).to be :doc
    end

    it "all_parts with size 1" do
      subject.instance_variable_set :@array, [hit1]
      expect(hit1).to receive(:item).and_return :doc
      expect(subject.fetch_doc).to be :doc
    end
  end

  describe "#to_all_parts" do
    let(:hit_no_part) do
      Relaton::Iso::Hit.new({ id: { publisher: "ISO", number: "19115", year: "2014" } })
    end

    let(:docid) { Relaton::Iso::Docidentifier.new(content: hit1.pubid) }
    let(:relation_doc) { Relaton::Iso::ItemData.new(docidentifier: [docid]) }

    it "fetch first doc when no part" do
      subject.instance_variable_set :@array, [hit_no_part]
      expect(hit_no_part).to receive(:item).and_return :doc
      expect(subject.to_all_parts).to be :doc
    end

    it "fetch all parts" do
      subject.instance_variable_set :@array, [hit1, hit2]
      expect(hit1).to receive(:item).and_return relation_doc
      all_parts_item = subject.to_all_parts
      expect(all_parts_item).to be_a Relaton::Iso::ItemData
      expect(all_parts_item.relation.size).to eq 2
      expect(all_parts_item.relation[0]).to be_a Relaton::Iso::Relation
      expect(all_parts_item.relation[0].bibitem).to be_a Relaton::Iso::ItemData
      expect(all_parts_item.relation[0].bibitem.docidentifier.size).to eq 1
      expect(all_parts_item.relation[0].bibitem.docidentifier[0].to_s).to eq "ISO 19115-1:2014"
      expect(all_parts_item.relation[1].bibitem.docidentifier[0].to_s).to eq "ISO 19115-2:2015"
    end
  end
end
