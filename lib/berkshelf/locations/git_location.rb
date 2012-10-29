module Berkshelf
  # @author Jamie Winsor <jamie@vialstudios.com>
  class GitLocation
    include Location

    set_location_key :git
    set_valid_options :ref, :branch, :tag

    attr_accessor :uri
    attr_accessor :branch

    alias_method :ref, :branch
    alias_method :tag, :branch

    # @param [#to_s] name
    # @param [Solve::Constraint] version_constraint
    # @param [Hash] options
    #
    # @option options [String] :git
    #   the Git URL to clone
    # @option options [String] :ref
    #   the commit hash or an alias to a commit hash to clone
    # @option options [String] :branch
    #   same as ref
    # @option options [String] :tag
    #   same as tag
    def initialize(name, version_constraint, options = {})
      @name               = name
      @version_constraint = version_constraint
      @uri                = options[:git]
      @branch             = options[:branch] || options[:ref] || options[:tag]

      Git.validate_uri!(@uri)
    end

    # @param [#to_s] destination
    #
    # @return [Berkshelf::CachedCookbook]
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

      cb_path = File.join(destination, "#{self.name}-#{Git.rev_parse(tmp_clone)}")
      FileUtils.rm_rf(cb_path)
      move_file(tmp_clone, cb_path)
              
      cached = CachedCookbook.from_store_path(cb_path)
      validate_cached(cached)

      set_downloaded_status(true)
      cached
    end

    def to_hash
      super.tap do |h|
        h[:value]  = self.uri
        h[:branch] = self.branch if branch
      end
    end

    def to_s
      s = "#{self.class.location_key}: '#{uri}'"
      s << " with branch: '#{branch}'" if branch
      s
    end

    private

      def git
        @git ||= Berkshelf::Git.new(uri)
      end
  end
end
