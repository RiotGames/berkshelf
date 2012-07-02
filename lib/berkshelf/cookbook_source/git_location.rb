module Berkshelf
  class CookbookSource
    # @author Jamie Winsor <jamie@vialstudios.com>
    class GitLocation
      include Location

      attr_accessor :uri
      attr_accessor :branch

      def initialize(name, options)
        @name = name
        @uri = options[:git]
        @branch = options[:branch] || options[:ref] || options[:tag]

        Git.validate_uri!(@uri)
      end

      def download(destination)
        tmp_clone = Dir.mktmpdir
        ::Berkshelf::Git.clone(uri, tmp_clone)
        ::Berkshelf::Git.checkout(tmp_clone, branch) if branch
        unless branch
          self.branch = ::Berkshelf::Git.rev_parse(tmp_clone)
        end

        unless File.chef_cookbook?(tmp_clone)
          msg = "Cookbook '#{name}' not found at git: #{uri}" 
          msg << " with branch '#{branch}'" if branch
          raise CookbookNotFound, msg
        end

        cb_path = File.join(destination, "#{self.name}-#{self.branch}")

        FileUtils.mv(tmp_clone, cb_path, :force => true)

        cb_path
      rescue Berkshelf::GitError
        msg = "Cookbook '#{name}' not found at git: #{uri}" 
        msg << " with branch '#{branch}'" if branch
        raise CookbookNotFound, msg
      end

      def to_s
        s = "git: '#{uri}'"
        s << " with branch '#{branch}'" if branch
        s
      end

      private

        def git
          @git ||= Berkshelf::Git.new(uri)
        end
    end
  end
end
