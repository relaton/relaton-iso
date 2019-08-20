RSpec.describe RelatonIso::HitCollection do
  it "sort by date" do
    resp = double
    expect(resp).to receive(:body).and_return(
      <<~RESP
        {"standards": [{"docRef": "ISO 123:2018"}, {"newProjectDate": "2019-02-01"}, {}]}
      RESP
    ).twice

    http = double
    expect(http).to receive(:use_ssl=)
    expect(http).to receive(:get).and_return resp

    expect(Net::HTTP).to receive(:new).and_return http

    hits = RelatonIso::HitCollection.new "ref"
    expect(hits.size).to eq 3
    expect(hits[0].hit["newProjectDate"]).to eq "2019-02-01"
    expect(hits[1].hit["docRef"]).to eq "ISO 123:2018"
  end
end
