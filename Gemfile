source "https://rubygems.org"

gem "rails", "~> 8.1.2"
gem "pg", "~> 1.1"
gem "puma", ">= 5.0"
gem "bcrypt", "~> 3.1.7"
gem "rack-cors"
gem "rack-attack"
gem "redis", "~> 5.0"
gem "sidekiq", "~> 8.1"
gem "jwt", "~> 3.1"
gem "blueprinter"
gem "lograge"
gem "rswag-api"
gem "stripe", "~> 13.0"
gem "tzinfo-data", platforms: %i[ windows jruby ]
gem "bootsnap", require: false
gem "kamal", require: false
gem "thruster", require: false

group :development, :test do
  gem "debug", platforms: %i[ mri windows ], require: "debug/prelude"
  gem "dotenv-rails"
  gem "rspec-rails", "~> 8.0"
  gem "rswag-specs"
  gem "factory_bot_rails"
  gem "faker"
  gem "shoulda-matchers"
  gem "database_cleaner-active_record"
  gem "brakeman", require: false
  gem "bundler-audit", require: false
  gem "rubocop-rails-omakase", require: false
  gem "rubocop-rspec", require: false
  gem "rubocop-performance", require: false
end

group :test do
  gem "webmock"
  gem "vcr"
  gem "rspec_junit_formatter"
end
