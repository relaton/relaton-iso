require "relaton/iso/processor"
require "relaton/iso/data_fetcher"

describe Relaton::Iso::Processor do
  it "#intialize" do
    expect(subject.instance_variable_get(:@short)).to eq :relaton_iso
    expect(subject.instance_variable_get(:@prefix)).to eq "ISO"
    expect(subject.instance_variable_get(:@defaultprefix)).to eq %r{^ISO(/IEC)?\s}
    expect(subject.instance_variable_get(:@idtype)).to eq "ISO"
    expect(subject.instance_variable_get(:@datasets)).to eq %w[iso-ics]
  end

  it "#get" do
    expect(Relaton::Iso::Bibliography).to receive(:get).with("19115", "2014", {})
    subject.get "19115", "2014", {}
  end

  it "#fetch_data" do
    expect(Relaton::Iso::DataFetcher).to receive(:fetch).with(output: "output", format: "xml")
    subject.fetch_data "iso-rss", output: "output", format: "xml"
  end

  it "#from_xml" do
    expect(Relaton::Iso::Item).to receive(:from_xml).with("<xml></xml>")
    subject.from_xml "<xml></xml>"
  end

  it "#from_yaml" do
    expect(Relaton::Iso::Item).to receive(:from_yaml).with("---\nkey: value\n")
    subject.from_yaml "---\nkey: value\n"
  end

  it "#grammar_hash" do
    expect(subject.grammar_hash).to be_a String
  end
end
