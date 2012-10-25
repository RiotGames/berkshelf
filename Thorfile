# encoding: utf-8
$:.push File.expand_path("../lib", __FILE__)

require 'bundler'
require 'bundler/setup'

require 'berkshelf'
require 'thor/rake_compat'

class Default < Thor
  include Thor::RakeCompat
  Bundler::GemHelper.install_tasks

  desc "build", "Build berkshelf-#{Berkshelf::VERSION}.gem into the pkg directory"
  def build
    Rake::Task["build"].execute
  end

  desc "install", "Build and install berkshelf-#{Berkshelf::VERSION}.gem into system gems"
  def install
    Rake::Task["install"].execute
  end

  desc "release", "Create tag v#{Berkshelf::VERSION} and build and push berkshelf-#{Berkshelf::VERSION}.gem to Rubygems"
  def release
    Rake::Task["release"].execute
  end

  desc "spec", "Run RSpec code examples"
  def spec
    exec "rspec --color --format=documentation spec"
  end

  desc "cucumber", "Run Cucumber features"
  def cucumber
    exec "cucumber --color --format progress --tags ~@no_run"
  end

  desc "ci", "Run all test suites"
  def ci
    ENV['CI'] = 'true' # Travis-CI also sets this, but set it here for local testing
    exec "rspec --tag ~chef_server --tag ~focus spec &&
          cucumber --format progress --tags ~@chef_server"
  end

  class VCR < Thor
    namespace :vcr

    desc "clean", "clean VCR cassettes"
    def clean
      FileUtils.rm_rf("spec/fixtures/vcr_cassettes")
    end
  end
end
