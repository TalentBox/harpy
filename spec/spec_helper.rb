require "harpy"
require "typhoeus"

Dir[File.expand_path("../support/**/*.rb", __FILE__)].each{|f| require f}

RSpec.configure do |config|
  config.after(:each) do
    Typhoeus::Expectation.clear
  end
end
