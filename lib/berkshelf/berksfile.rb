require 'chef/cookbook/chefignore'

module Berkshelf
  # @author Jamie Winsor <jamie@vialstudios.com>
  class Berksfile
    extend Forwardable

    class << self
      # @param [String] file
      #   a path on disk to a Berksfile to instantiate from
      #
      # @return [Berksfile]
      def from_file(file)
        content = File.read(file)
        object = new(file)
        object.load(content)
      rescue Errno::ENOENT => e
        raise BerksfileNotFound, "No Berksfile or Berksfile.lock found at: #{file}"
      end

      # @deprecated Use {Berkshelf::Installer.install} with a :path option instead.
      def vendor(cookbooks, path)
        ::Berkshelf.ui.deprecated 'The Berkshelf::Berksfile#vendor method has been deprecated. Please use Berkshelf::Installer.install with a :path option instead.'
        ::Berkshelf::Installer.install(cookbooks: cookbooks, path: path)
      end
    end

    @@active_group = nil

    # @return [String]
    #   The path on disk to the file representing this instance of Berksfile
    attr_reader :filepath

    # @return [Berkshelf::Downloader]
    attr_reader :downloader

    # @return [Array<Berkshelf::CachedCookbook>]
    attr_reader :cached_cookbooks

    def_delegator :downloader, :add_location
    def_delegator :downloader, :locations

    def initialize(path)
      @filepath = path.to_s
      @sources = Hash.new
      @downloader = Downloader.new(Berkshelf.cookbook_store)
      @cached_cookbooks = nil
    end

    # @return [String]
    #   the shasum for the Berksfile
    def sha
      @sha ||= Digest::SHA1.hexdigest File.read(filepath)
    end

    # Add a cookbook source to the Berksfile to be retrieved and have it's dependencies recursively retrieved
    # and resolved.
    #
    # @example a cookbook source that will be retrieved from one of the default locations
    #   cookbook 'artifact'
    #
    # @example a cookbook source that will be retrieved from a path on disk
    #   cookbook 'artifact', path: '/Users/reset/code/artifact'
    #
    # @example a cookbook source that will be retrieved from a remote community site
    #   cookbook 'artifact', site: 'http://cookbooks.opscode.com/api/v1/cookbooks'
    #
    # @example a cookbook source that will be retrieved from the latest API of the Opscode Community Site
    #   cookbook 'artifact', site: :opscode
    #
    # @example a cookbook source that will be retrieved from a Git server
    #   cookbook 'artifact', git: 'git://github.com/RiotGames/artifact-cookbook.git'
    #
    # @example a cookbook source that will be retrieved from a Chef API (Chef Server)
    #   cookbook 'artifact', chef_api: 'https://api.opscode.com/organizations/vialstudios', node_name: 'reset', client_key: '/Users/reset/.chef/knife.rb'
    #
    # @example a cookbook source that will be retrieved from a Chef API using your Berkshelf config
    #   cookbook 'artifact', chef_api: :config
    #
    # @overload cookbook(name, version_constraint, options = {})
    #   @param [#to_s] name
    #   @param [#to_s] version_constraint
    #   @param [Hash] options
    #
    #   @option options [Symbol, Array] :group
    #     the group or groups that the cookbook belongs to
    #   @option options [String, Symbol] :chef_api
    #     a URL to a Chef API. Alternatively the symbol :config can be provided
    #     which will instantiate this location with the values found in your
    #     Berkshelf configuration.
    #   @option options [String] :site
    #     a URL pointing to a community API endpoint
    #   @option options [String] :path
    #     a filepath to the cookbook on your local disk
    #   @option options [String] :git
    #     the Git URL to clone
    #
    #   @see ChefAPILocation
    #   @see SiteLocation
    #   @see PathLocation
    #   @see GitLocation
    # @overload cookbook(name, options = {})
    #   @param [#to_s] name
    #   @param [Hash] options
    #
    #   @option options [Symbol, Array] :group
    #     the group or groups that the cookbook belongs to
    #   @option options [String, Symbol] :chef_api
    #     a URL to a Chef API. Alternatively the symbol :config can be provided
    #     which will instantiate this location with the values found in your
    #     Berkshelf configuration.
    #   @option options [String] :site
    #     a URL pointing to a community API endpoint
    #   @option options [String] :path
    #     a filepath to the cookbook on your local disk
    #   @option options [String] :git
    #     the Git URL to clone
    #
    #   @see ChefAPILocation
    #   @see SiteLocation
    #   @see PathLocation
    #   @see GitLocation
    def cookbook(*args)
      options = args.last.is_a?(Hash) ? args.pop : Hash.new
      name, constraint = args

      options[:group] = Array(options[:group])

      if @@active_group
        options[:group] += @@active_group
      end

      add_source(name, constraint, options)
    end

    def group(*args)
      @@active_group = args
      yield
      @@active_group = nil
    end

    # Use a Cookbook metadata file to determine additional cookbook sources to retrieve. All
    # sources found in the metadata will use the default locations set in the Berksfile (if any are set)
    # or the default locations defined by Berkshelf.
    #
    # @param [Hash] options
    #
    # @option options [String] :path
    #   path to the metadata file
    def metadata(options = {})
      path = options[:path] || File.dirname(filepath)

      metadata_file = Berkshelf.find_metadata(path)

      unless metadata_file
        raise CookbookNotFound, "No 'metadata.rb' found at #{path}"
      end

      metadata = Chef::Cookbook::Metadata.new
      metadata.from_file(metadata_file.to_s)

      name = if metadata.name.empty? || metadata.name.nil?
        File.basename(File.dirname(metadata_file))
      else
        metadata.name
      end

      constraint = "= #{metadata.version}"

      add_source(name, constraint, path: File.dirname(metadata_file))
    end

    # Add a 'Site' default location which will be used to resolve cookbook sources that do not
    # contain an explicit location.
    #
    # @note
    #   specifying the symbol :opscode as the value of the site default location is an alias for the
    #   latest API of the Opscode Community Site.
    #
    # @example
    #   site :opscode
    #   site "http://cookbooks.opscode.com/api/v1/cookbooks"
    #
    # @param [String, Symbol] value
    #
    # @return [Hash]
    def site(value)
      add_location(:site, value)
    end

    # Add a 'Chef API' default location which will be used to resolve cookbook sources that do not
    # contain an explicit location.
    #
    # @note
    #   specifying the symbol :config as the value of the chef_api default location will attempt to use the
    #   contents of your Berkshelf configuration to find the Chef API to interact with.
    #
    # @example using the symbol :config to add a Chef API default location
    #   chef_api :config
    #
    # @example using a URL, node_name, and client_key to add a Chef API default location
    #   chef_api "https://api.opscode.com/organizations/vialstudios", node_name: "reset", client_key: "/Users/reset/.chef/knife.rb"
    #
    # @param [String, Symbol] value
    # @param [Hash] options
    #
    # @return [Hash]
    def chef_api(value, options = {})
      add_location(:chef_api, value, options)
    end

    # Add a source of the given name and constraint to the array of sources.
    #
    # @param [String] name
    #   the name of the source to add
    # @param [String, Solve::Constraint] constraint
    #   the constraint to lock the source to
    # @param [Hash] options
    #
    # @raise [DuplicateSourceDefined] if a source is added whose name conflicts
    #   with a source who has already been added.
    #
    # @return [Array<Berkshelf::CookbookSource]
    def add_source(name, constraint = nil, options = {})
      if has_source?(name)
        # Only raise an exception if the source is a true duplicate
        groups = (options[:group].nil? || options[:group].empty?) ? [:default] : options[:group]
        if !(@sources[name].groups & groups).empty?
          raise DuplicateSourceDefined, "Berksfile contains multiple sources named '#{name}'. Use only one, or put them in different groups."
        end
      end

      options[:constraint] = constraint

      @sources[name] = CookbookSource.new(name, options)
    end

    # @param [#to_s] source
    #   the source to remove
    #
    # @return [Berkshelf::CookbookSource]
    def remove_source(source)
      @sources.delete(source.to_s)
    end

    # @param [#to_s] source
    #   the source to check presence of
    #
    # @return [Boolean]
    def has_source?(source)
      @sources.has_key?(source.to_s)
    end

    # @option options [Symbol, Array] :except
    #   Group(s) to exclude to exclude from the returned Array of sources
    #   group to not be installed
    # @option options [Symbol, Array] :only
    #   Group(s) to include which will cause any sources marked as a member of the
    #   group to be installed and all others to be ignored
    # @option cookbooks [String, Array] :cookbooks
    #   Names of the cookbooks to retrieve sources for
    #
    # @raise [Berkshelf::ArgumentError] if a value for both :except and :only is provided
    #
    # @return [Array<Berkshelf::CookbookSource>]
    def sources(options = {})
      l_sources = @sources.collect { |name, source| source }.flatten

      except    = Array(options.fetch(:except, nil)).collect(&:to_sym)
      only      = Array(options.fetch(:only, nil)).collect(&:to_sym)

      case
      when !except.empty? && !only.empty?
        raise Berkshelf::ArgumentError, "Cannot specify both :except and :only"
      when !except.empty?
        l_sources.select { |source| (except & source.groups).empty? }
      when !only.empty?
        l_sources.select { |source| !(only & source.groups).empty? }
      else
        l_sources
      end
    end

    # @return [Hash]
    #   a hash containing group names as keys and an array of CookbookSources
    #   that are a member of that group as values
    #
    #   Example:
    #     {
    #       nautilus: [
    #         #<Berkshelf::CookbookSource @name="nginx">,
    #         #<Berkshelf::CookbookSource @name="mysql">,
    #       ],
    #       skarner: [
    #         #<Berkshelf::CookbookSource @name="nginx">
    #       ]
    #     }
    def groups
      {}.tap do |groups|
        sources.each do |source|
          source.groups.each do |group|
            groups[group] ||= []
            groups[group] << source
          end
        end
      end
    end

    # @param [String] name
    #   name of the source to return
    #
    # @return [Berkshelf::CookbookSource]
    def [](name)
      @sources[name]
    end
    alias_method :get_source, :[]

    # @deprecated Use {Berkshelf::Installer.install} instead.
    def install(options = {})
      ::Berkshelf.ui.deprecated 'The Berkshelf::Berksfile#install method has been deprecated. Please use Berkshelf::Installer.install instead.'
      ::Berkshelf::Installer.install(options)
    end

    # @deprecated Use {Berkshelf::Updater.update} instead.
    def update(options = {})
      ::Berkshelf.ui.deprecated 'The Berkshelf::Berksfile#update method has been deprecated. Please use Berkshelf::Updater.update instead.'
      ::Berkshelf::Updater.update(options)
    end

    # Get a list of all the cookbooks which have newer versions found on the community
    # site versus what your current constraints allow
    #
    # @option options [Symbol, Array] :except
    #   Group(s) to exclude which will cause any sources marked as a member of the
    #   group to not be installed
    # @option options [Symbol, Array] :only
    #   Group(s) to include which will cause any sources marked as a member of the
    #   group to be installed and all others to be ignored
    # @option cookbooks [String, Array] :cookbooks
    #   Names of the cookbooks to retrieve sources for
    #
    # @return [Hash]
    #   a hash of cached cookbooks and their latest version. An empty hash is returned
    #   if there are no newer cookbooks for any of your sources
    #
    # @example
    #   berksfile.outdated => {
    #     <#CachedCookbook name="artifact"> => "0.11.2"
    #   }
    def outdated(options = {})
      outdated = Hash.new

      sources(options).each do |cookbook|
        location = cookbook.location || Location.init(cookbook.name, cookbook.version_constraint)

        if location.is_a?(SiteLocation)
          latest_version = SiteLocation.new(cookbook.name, cookbook.version_constraint).latest_version[0]

          unless cookbook.version_constraint.satisfies?(latest_version)
            outdated[cookbook] = latest_version
          end
        end
      end

      outdated
    end

    # @option options [String] :server_url
    #   URL to the Chef API
    # @option options [String] :client_name
    #   name of the client used to authenticate with the Chef API
    # @option options [String] :client_key
    #   filepath to the client's private key used to authenticate with
    #   the Chef API
    # @option options [String] :organization
    #   the Organization to connect to. This is only used if you are connecting to
    #   private Chef or hosted Chef
    # @option options [Boolean] :force Upload the Cookbook even if the version
    #   already exists and is frozen on the target Chef Server
    # @option options [Boolean] :freeze Freeze the uploaded Cookbook on the Chef
    #   Server so that it cannot be overwritten
    # @option options [Symbol, Array] :except
    #   Group(s) to exclude which will cause any sources marked as a member of the
    #   group to not be installed
    # @option options [Symbol, Array] :only
    #   Group(s) to include which will cause any sources marked as a member of the
    #   group to be installed and all others to be ignored
    # @option cookbooks [String, Array] :cookbooks
    #   Names of the cookbooks to retrieve sources for
    # @option options [Hash] :params
    #   URI query unencoded key/value pairs
    # @option options [Hash] :headers
    #   unencoded HTTP header key/value pairs
    # @option options [Hash] :request
    #   request options
    # @option options [Hash] :ssl
    #   SSL options
    # @option options [URI, String, Hash] :proxy
    #   URI, String, or Hash of HTTP proxy options
    #
    # @raise [UploadFailure] if you are uploading cookbooks with an invalid or not-specified client key
    def upload(options = {})
      uploader = Uploader.new(options)
      solution = resolve(options)
      solution.each do |cb|
        Berkshelf.formatter.upload cb.cookbook_name, cb.version, options[:server_url]
        uploader.upload(cb, options)
      end
      if options[:skip_dependencies]
        missing_cookbooks = options.fetch(:cookbooks, nil) - solution.map(&:cookbook_name)
        unless missing_cookbooks.empty?
          msg = "Unable to upload cookbooks: #{missing_cookbooks.sort.join(', ')}\n"
          msg << "Specified cookbooks must be defined within the Berkshelf file when using the `--skip-dependencies` option"
          raise ExplicitCookbookNotFound.new(msg)
        end
      end
    rescue Ridley::Errors::ClientKeyFileNotFound => e
      msg = "Could not upload cookbooks: Missing Chef client key: '#{Berkshelf::Config.instance.chef.client_key}'."
      msg << " Generate or update your Berkshelf configuration that contains a valid path to a Chef client key."
      raise UploadFailure, msg
    end

    # Finds a solution for the Berksfile and returns an array of CachedCookbooks.
    #
    # @option options [Symbol, Array] :except
    #   Group(s) to exclude which will cause any sources marked as a member of the
    #   group to not be installed
    # @option options [Symbol, Array] :only
    #   Group(s) to include which will cause any sources marked as a member of the
    #   group to be installed and all others to be ignored
    # @option cookbooks [String, Array] :cookbooks
    #   Names of the cookbooks to retrieve sources for
    #
    # @return [Array<Berkshelf::CachedCookbooks]
    def resolve(options = {})
      resolver(options).resolve(options.fetch(:cookbooks, nil))
    end

    # Builds a Resolver instance
    #
    # @option options [Symbol, Array] :except
    #   Group(s) to exclude which will cause any sources marked as a member of the
    #   group to not be installed
    # @option options [Symbol, Array] :only
    #   Group(s) to include which will cause any sources marked as a member of the
    #   group to be installed and all others to be ignored
    # @option cookbooks [String, Array] :cookbooks
    #   Names of the cookbooks to retrieve sources for
    #
    # @return <Berkshelf::Resolver>
    def resolver(options={})
      Resolver.new(
        self.downloader,
        sources: sources(options),
        skip_dependencies: options[:skip_dependencies]
      )
    end

    # Reload this instance of Berksfile with the given content. The content
    # is a string that may contain terms from the included DSL.
    #
    # @param [String] content
    #
    # @raise [BerksfileReadError] if Berksfile contains bad content
    #
    # @return [Berksfile]
    def load(content)
      begin
        instance_eval(content)
      rescue => e
        raise BerksfileReadError.new(e), "An error occurred while reading the Berksfile: #{e.to_s}"
      end
      self
    end

    # Get the lockfile corresponding to this Berksfile. This is necessary because
    # the user can specify a different path to the Berksfile. So assuming the lockfile
    # is named "Berksfile.lock" is a poor assumption.
    #
    # @return [::Berkshelf::Lockfile]
    #   the lockfile corresponding to this berksfile, or a new Lockfile if one does
    #   not exist
    def lockfile
      lockfile_path = filepath.to_s + '.lock'

      begin
        ::Berkshelf::Lockfile.from_file(lockfile_path)
      rescue ::Berkshelf::LockfileNotFound
        ::Berkshelf::Lockfile.new(lockfile_path, [])
      end
    end

  end
end
