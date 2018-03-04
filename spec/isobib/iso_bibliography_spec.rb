require "isobib/iso_bibliography"

RSpec.describe Isobib::IsoBibliography do
  it "search for iso bibliongraphic items" do
    results = Isobib::IsoBibliography.search("19155")
    expect(results.length).to eq 2
  end
end