require 'chef/knife'

module Berkshelf
  class BerksUpload < Chef::Knife
    deps do
      require 'berkshelf'
    end

    banner "knife berks upload (options)"

    option :without,
      :short => "-W WITHOUT",
      :long => "--without WITHOUT",
      :description => "Exclude cookbooks that are in these groups",
      :proc => lambda { |w| w.split(",") },
      :default => Array.new

    option :freeze,
      :long => "--freeze",
      :description => "Freeze the uploaded cookbooks so that they cannot be overwritten",
      :boolean => true,
      :default => false

    option :force,
      :long => "--force",
      :description => "Upload all cookbooks even if a frozen one exists on the target Chef Server",
      :boolean => true,
      :default => false

    def run
      ::Berkshelf.ui = ui
      cookbook_file = ::Berkshelf::Berksfile.from_file(File.join(Dir.pwd, "Berksfile"))
      cookbook_file.upload(Chef::Config[:chef_server_url], config)
    rescue BerkshelfError => e
      Berkshelf.ui.fatal e
      exit e.status_code
    end
  end
end
