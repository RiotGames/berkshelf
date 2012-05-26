require 'kcd/cookbook/common'

module KnifeCookbookDependencies
  class Cookbook
    class Download

      include KCD::Cookbook::Common::Path

      attr_reader :cookbook

      def initialize(args, cookbook)
        @version = args[1]
        @cookbook = cookbook
      end

      def prepare
        cookbook.add_version_constraint(@version)
      end

      def download(show_output)
        FileUtils.mkdir_p KCD::TMP_DIRECTORY
        csd = Chef::Knife::CookbookSiteDownload.new([cookbook.name, cookbook.latest_constrained_version.to_s, "--file", cookbook.download_filename])

        output = ''
        cookbook.rescue_404 do
          output = KCD::KnifeUtils.capture_knife_output(csd)
        end

        if show_output
          output.split(/\r?\n/).each { |x| KCD.ui.info(x) }
        end
      end

      def identifier
        cookbook.latest_constrained_version
      end

      def unpack(location, options)
        clean     if options[:clean]
        download  if options[:download]

        unless cookbook.downloaded_archive_exists? or File.directory?(location)
          # TODO raise friendly error
          raise "Archive hasn't been downloaded yet"
        end

        if cookbook.downloaded_archive_exists?
          Archive::Tar::Minitar.unpack(Zlib::GzipReader.new(File.open(cookbook.download_filename)), location)
        end

        return true
      end

      def latest_constrained_version
        cookbook.versions.reverse.each do |v|
          return v if cookbook.version_constraints_include? v
        end
        KCD.ui.fatal "No version available to fit the following constraints for #{@name}: #{version_constraints.inspect}\nAvailable versions: #{versions.inspect}"
        exit 1
      end

      def versions
        cookbook.cookbook_data['versions'].collect { |v| DepSelector::Version.new(v.split(/\//).last.gsub(/_/, '.')) }.sort
      end

    end
  end
end
