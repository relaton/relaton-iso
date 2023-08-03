describe RelatonIso::Config do
  after { RelatonIso::Config.instance_variable_set :@configuration, nil }

  it "configure" do
    RelatonIso::Config.configure do |conf|
      conf.logger = :logger
    end
    expect(RelatonIso::Config.configuration.logger).to eq :logger
  end
end
