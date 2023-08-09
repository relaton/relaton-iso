describe RelatonIso do
  after { RelatonIso.instance_variable_set :@configuration, nil }

  it "configure" do
    RelatonIso.configure do |conf|
      conf.logger = :logger
    end
    expect(RelatonIso.configuration.logger).to eq :logger
  end
end
