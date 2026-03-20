require "bundler/gem_tasks"
require "rspec/core/rake_task"

RSpec::Core::RakeTask.new(:spec)

task :default => :spec

namespace :spec do
  desc "Download latest ISO index fixture from relaton-data-iso"
  task :update_index do
    require "net/http"
    require "uri"

    url = "https://raw.githubusercontent.com/relaton/relaton-data-iso/data-v2/index-v1.zip"
    dest = File.join(__dir__, "spec", "fixtures", "index-v1.zip")

    puts "Downloading #{url} ..."
    uri = URI.parse(url)
    response = Net::HTTP.get_response(uri)

    if response.is_a?(Net::HTTPSuccess)
      File.binwrite(dest, response.body)
      puts "Updated #{dest} (#{response.body.bytesize} bytes)"
    else
      abort "Failed to download: HTTP #{response.code}"
    end
  end
end
