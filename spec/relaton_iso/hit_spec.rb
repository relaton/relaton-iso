RSpec.describe RelatonIso::Hit do
  context "sort weight" do
    it "Deleted" do
      hit = RelatonIso::Hit.new({ status: "Deleted" })
      expect(hit.sort_weight).to eq 3
    end

    it "other" do
      hit = RelatonIso::Hit.new({ status: nil })
      expect(hit.sort_weight).to eq 4
    end
  end
end
