require 'kitchen/cli'

module Berkshelf
  class TestCommand < Kitchen::CLI
    namespace "test"
  end

  class Cli < Thor
    register(Berkshelf::TestCommand, 'test', 'test [COMMAND]', 'Testing tasks for your cookbook', hide: true)
  end
end
