require 'spec_helper'

module KnifeCookbookDependencies
  describe CachedCookbook do
    describe "ClassMethods" do
      subject { CachedCookbook }

      describe "#from_path" do
        before(:each) do
          @cached_cb = subject.from_path(fixtures_path.join("cookbooks", "example_cookbook-0.5.0"))
        end

        it "returns an instance of CachedCookbook" do
          @cached_cb.should be_a(CachedCookbook)
        end

        it "sets a version number" do
          @cached_cb.version.should eql("0.5.0")
        end

        context "given a path that does not contain a cookbook" do
          it "returns nil" do
            subject.from_path(tmp_path).should be_nil
          end
        end

        context "given a path that does not match the CachedCookbook dirname format" do
          it "returns nil" do
            subject.from_path(fixtures_path.join("cookbooks", "example_cookbook")).should be_nil
          end
        end
      end

      describe "#checksum" do
        it "returns a checksum of the given filepath" do
          subject.checksum(fixtures_path.join("cookbooks", "example_cookbook-0.5.0", "README.md")).should eql("6e21094b7a920e374e7261f50e9c4eef")
        end

        context "given path does not exist" do
          it "raises an Errno::ENOENT error" do
            lambda {
              subject.checksum(fixtures_path.join("notexisting.file"))
            }.should raise_error(Errno::ENOENT)
          end
        end
      end
    end

    describe "#checksums" do
      let(:cb_path) { fixtures_path.join("cookbooks", "example_cookbook-0.5.0") }
      subject { CachedCookbook.from_path(cb_path) }

      it "returns a Hash that has checksum values of the files on disk as keys" do
        subject.checksums.should have_key("da97c94bb6acb2b7900cbf951654fea3")
      end

      it "returns a Mash that has a 'checksum' key and value" do
        subject.checksums["da97c94bb6acb2b7900cbf951654fea3"].should eql(cb_path.join("recipes/default.rb").to_s)
        puts subject.checksums
      end
    end

    describe "#validate!" do
      it "returns true if the cookbook of the given name and version is valid" do
        @cb = CachedCookbook.from_path(fixtures_path.join("cookbooks", "example_cookbook-0.5.0"))

        @cb.validate!.should be_true
      end

      it "raises CookbookSyntaxError if the cookbook contains invalid ruby files" do
        @cb = CachedCookbook.from_path(fixtures_path.join("cookbooks", "invalid_ruby_files-1.0.0"))

        lambda {
          @cb.validate!
        }.should raise_error(CookbookSyntaxError)
      end

      it "raises CookbookSyntaxError if the cookbook contains invalid template files" do
        @cb = CachedCookbook.from_path(fixtures_path.join("cookbooks", "invalid_template_files-1.0.0"))

        lambda {
          @cb.validate!
        }.should raise_error(CookbookSyntaxError)
      end
    end

    describe "#to_hash" do
      before(:each) do
        cb = CachedCookbook.from_path(fixtures_path.join("cookbooks", "example_cookbook-0.5.0"))
        @hash = cb.to_hash
      end

      let(:cookbook_name) { "example_cookbook" }
      let(:cookbook_version) { "0.5.0" }

      it "has a 'recipes' key with an Array value" do
        @hash.should have_key('recipes')
        @hash['recipes'].should be_a(Array)
      end

      it "has a 'definitions' key with an Array value" do
        @hash.should have_key('definitions')
        @hash['definitions'].should be_a(Array)
      end

      it "has a 'libraries' key with an Array value" do
        @hash.should have_key('libraries')
        @hash['libraries'].should be_a(Array)
      end

      it "has an 'attributes' key with an Array value" do
        @hash.should have_key('attributes')
        @hash['attributes'].should be_a(Array)
      end

      it "has a 'files' key with an Array value" do
        @hash.should have_key('files')
        @hash['files'].should be_a(Array)
      end

      it "has a 'templates' key with an Array value" do
        @hash.should have_key('templates')
        @hash['templates'].should be_a(Array)
      end

      it "has a 'resources' key with an Array value" do
        @hash.should have_key('resources')
        @hash['resources'].should be_a(Array)
      end

      it "has a 'providers' key with an Array value" do
        @hash.should have_key('providers')
        @hash['providers'].should be_a(Array)
      end

      it "has a 'root_files' key with an Array value" do
        @hash.should have_key('root_files')
        @hash['root_files'].should be_a(Array)
      end

      it "has a 'cookbook_name' key with a String value" do
        @hash.should have_key('cookbook_name')
        @hash['cookbook_name'].should be_a(String)
      end

      it "has a 'metadata' key with a Cookbook::Metadata value" do
        @hash.should have_key('metadata')
        @hash['metadata'].should be_a(Chef::Cookbook::Metadata)
      end

      it "has a 'version' key with a String value" do
        @hash.should have_key('version')
        @hash['version'].should be_a(String)
      end

      it "has a 'name' key with a String value" do
        @hash.should have_key('name')
        @hash['name'].should be_a(String)
      end

      it "has a value containing the cookbook name and version separated by a dash for 'name'" do
        name, version = @hash['name'].split('-')

        name.should eql(cookbook_name)
        version.should eql(cookbook_version)
      end

      it "has a 'chef_type' key with 'cookbook_version' as the value" do
        @hash.should have_key('chef_type')
        @hash['chef_type'].should eql("cookbook_version")
      end
    end

    describe "#to_json" do
      before(:each) do
        cb = CachedCookbook.from_path(fixtures_path.join("cookbooks", "example_cookbook-0.5.0"))
        @json = cb.to_json
      end

      it "has a 'json_class' key with 'Chef::CookbookVersion' as the value" do
        @json.should have_json_path('json_class')
        parse_json(@json)['json_class'].should eql("Chef::CookbookVersion")
      end
    end
  end
end
