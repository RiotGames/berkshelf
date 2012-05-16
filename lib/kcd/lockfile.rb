module KnifeCookbookDependencies
  class Lockfile
    def initialize(cookbooks)
      @cookbooks = cookbooks
    end

    def write(filename = KCD::DEFAULT_FILENAME)
      content = @cookbooks.map do |cookbook|
                  get_cookbook_definition(cookbook)
                end.join("\n")
      File::open("#{filename}.lock", "wb") { |f| f.write content }
    end

    def get_cookbook_definition(cookbook)
      definition = "cookbook '#{cookbook.name}'"

      if cookbook.from_git?
        definition += ", :git => '#{cookbook.git_repo}', :ref => '#{cookbook.git_ref || 'HEAD'}'"
      elsif cookbook.from_path?
        definition += ", :path => '#{cookbook.local_path}'"
      else
        definition += ", :locked_version => '#{cookbook.locked_version}'"
      end

      return definition
    end
  end
end
