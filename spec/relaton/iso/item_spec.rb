describe Relaton::Iso::Item do
  let(:intput_yaml) { File.read "spec/fixtures/item.yaml", encoding: "UTF-8" }
  let(:item) { described_class.from_yaml intput_yaml }

  context "round trip" do
    it "to YAML" do
      input_hash = YAML.safe_load(intput_yaml)
      output_hash = YAML.safe_load(described_class.to_yaml(item))
      expect(output_hash).to match(**input_hash)
    end
  end
end
