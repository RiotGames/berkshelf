require 'spork'

Spork.prefork do
  require 'rspec'
  require 'webmock/rspec'
  require 'berkshelf/api/rspec'

  Dir['spec/support/**/*.rb'].each { |f| require File.expand_path(f) }

  RSpec.configure do |config|
    config.include Berkshelf::RSpec::FileSystemMatchers
    config.include Berkshelf::RSpec::ChefAPI
    config.include Berkshelf::RSpec::ChefServer
    config.include Berkshelf::RSpec::Git
    config.include Berkshelf::RSpec::PathHelpers
    config.include Berkshelf::API::RSpec

    # Run specs in random order to surface order dependencies. If you find an
    # order dependency and want to debug it, you can fix the order by
    # providing the seed, which is printed after each run.
    #     --seed 1234
    config.order = 'random'

    config.expect_with :rspec do |c|
      c.syntax = :expect
    end

    # Allow tests to isolate a specific test using +focus: true+. If nothing
    # is focused, then all tests are executed.
    config.filter_run focus: true
    config.run_all_when_everything_filtered = true

    config.mock_with :rspec
    config.treat_symbols_as_metadata_keys_with_true_values = true

    config.before(:suite) do
      WebMock.disable_net_connect!(allow_localhost: true, net_http_connect_on_start: true)
      Berkshelf::RSpec::ChefServer.start
      Berkshelf::API::RSpec::Server.start
    end

    config.before(:all) do
      ENV['BERKSHELF_PATH'] = berkshelf_path.to_s
    end

    config.before(:each) do
      Berkshelf::API::RSpec::Server.clear_cache
      clean_tmp_path
      Berkshelf.initialize_filesystem
      Berkshelf::CookbookStore.instance.initialize_filesystem
      reload_configs

      Berkshelf.reset!

      # Don't output anything
      Berkshelf.ui.mute!
      Berkshelf.set_format(:null)
    end
  end

  def capture(stream)
    begin
      stream = stream.to_s
      eval "$#{stream} = StringIO.new"
      yield
      result = eval("$#{stream}").string
    ensure
      eval("$#{stream} = #{stream.upcase}")
    end

    result
  end
end

Spork.each_run do
  require 'berkshelf'

  module Berkshelf
    class GitLocation < Location::ScmLocation
      include Berkshelf::RSpec::Git

      alias :real_clone :clone
      def clone
        fake_remote = generate_fake_git_remote(uri, tags: @branch ? [@branch] : [])
        tmp_clone = File.join(self.class.tmpdir, uri.gsub(/[\/:]/,'-'))
        @uri = "file://#{fake_remote}"
        real_clone
      end
    end
  end
end
