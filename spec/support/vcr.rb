require "vcr"

VCR.configure do |config|
  config.cassette_library_dir = "spec/vcr_cassettes"
  config.default_cassette_options = {
    clean_outdated_http_interactions: true,
    re_record_interval: 7 * 24 * 3600,
    record: :once,
    preserve_exact_body_bytes: true,
  }
  config.hook_into :webmock
  config.configure_rspec_metadata!

  # Ignore index download requests — handled by a global WebMock stub instead
  config.ignore_request do |request|
    URI(request.uri).path.end_with?("index-v1.zip")
  end
end
