require "webmock/rspec"

INDEX_ZIP_PATH = File.join(__dir__, "..", "fixtures", "index-v1.zip")

INDEX_STUB = proc do
  WebMock.stub_request(:get, /index-v1\.zip/)
    .to_return(lambda { |_req|
      { status: 200, body: File.binread(INDEX_ZIP_PATH), headers: { "Content-Type" => "application/zip" } }
    })
end

RSpec.configure do |config|
  config.before(:suite) do
    Relaton::Index.configure do |c|
      c.storage_dir = Dir.mktmpdir("relaton-iso-test")
    end
    Relaton::Index.close(:iso)

    INDEX_STUB.call
  end

  config.before(:each) do
    WebMock.reset!
    WebMock.disable_net_connect!
    INDEX_STUB.call
  end
end
