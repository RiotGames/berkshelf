module Berkshelf
  class GithubLocation < GitLocation
    HOST = 'github.com'
    def initialize(dependency, options = {})
      protocol = Berkshelf::Config.instance.github.protocol || :git
      case protocol
      when :ssh
        options[:git] = "git@#{HOST}:#{options.delete(:github)}.git"
      when :https
        options[:git] = "https://#{HOST}/#{options.delete(:github)}.git"
      else
        # if some bizarre value is provided, treat it as :git
        options[:git] = "git://#{HOST}/#{options.delete(:github)}.git"
      end
      super
    end
  end
end
