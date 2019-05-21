ruby '2.4.6'

source 'https://rubygems.org'

# Bundle edge Rails instead: gem 'rails', github: 'rails/rails'
gem 'rails', '4.2.0'

# Use postgres as the database for Active Record
gem 'pg', '~> 0.21.0'

# Use SCSS for stylesheets
gem 'sass-rails'

# Use Uglifier as compressor for JavaScript assets
gem 'uglifier', '>= 3.0'

gem 'unicorn', '~> 4.9.0'

# Use CoffeeScript for .js.coffee assets and views
gem 'coffee-rails', '~> 4.0.0'

# See https://github.com/sstephenson/execjs#readme for more supported runtimes
gem 'therubyracer', platforms: :ruby

# Use jquery as the JavaScript library
gem 'jquery-rails'

# Build JSON APIs with ease. Read more: https://github.com/rails/jbuilder
gem 'active_model_serializers'
gem 'quiet_assets', group: :development

gem 'bower-rails'
# gem 'emcee', github: 'openjournals/emcee', branch:'fix_attempt'
gem 'emcee', github: 'openjournals/emcee'
gem 'rack-streaming-proxy'

gem 'rails_12factor', group: :production

gem 'arxiv', :git => "git://github.com/marcrohloff/arxiv.git", :branch => "cleanup"
gem 'responders'

group :doc do
  # bundle exec rake doc:rails generates the API under doc/api.
  gem 'sdoc', require: false
end

# Auth/Users
gem 'omniauth', '~> 1.2'

gem 'omniauth-orcid', :git => "git://github.com/gthorisson/omniauth-orcid.git"
gem 'aasm'
gem 'cancancan', '~> 1.8'

gem 'firebase'

# Needs to be available in development for generators
group :test, :development do
  gem 'rspec-rails', '~> 3.1'
end

group :test do
  gem 'test_after_commit'
  gem 'shoulda-matchers', '~> 2.6.1'
  gem 'factory_girl_rails', '~> 4.4.1'
  gem 'webmock', '~> 2.1.0'
end

# Use ActiveModel has_secure_password
# gem 'bcrypt-ruby', '~> 3.1.2'

# Use unicorn as the app server
# gem 'unicorn'

# Use Capistrano for deployment
# gem 'capistrano', group: :development

# Use pry
gem 'pry', group: [:development, :test]
