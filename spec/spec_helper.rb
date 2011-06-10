require "harpy"
require "typhoeus"

Dir[File.expand_path("../support/**/*.rb", __FILE__)].each{|f| require f}

# Do not allow external connections
Typhoeus::Hydra.allow_net_connect = false

RSpec.configure do |config|
  config.after(:each) do
    Typhoeus::Hydra.hydra.clear_stubs
  end
end