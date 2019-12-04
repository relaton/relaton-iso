RSpec.describe RelatonIso do
  it "has a version number" do
    expect(RelatonIso::VERSION).not_to be nil
  end

  it "returs grammar hash" do
    hash = RelatonIso.grammar_hash
    expect(hash).to be_instance_of String
    expect(hash.size).to eq 32
  end
end
