require 'chef/knife'

module KnifeCookbookDependencies
  class CookbookDependenciesInstall < Chef::Knife
    deps do
      require 'kcd'
    end
    
    banner "knife cookbook dependencies install (options)"

    option :without,
      :short => "-W WITHOUT",
      :long => "--without WITHOUT",
      :description => "Exclude cookbooks that are in these groups",
      :proc => lambda { |w| w.split(",") },
      :default => Array.new

    def run
      ::KCD.ui = ui
      cookbook_file = ::KCD::Cookbookfile.from_file(File.join(Dir.pwd, "Cookbookfile"))
      cookbook_file.install(config)
    rescue KCDError => e
      KCD.ui.fatal e
      exit e.status_code
    end
  end
end
