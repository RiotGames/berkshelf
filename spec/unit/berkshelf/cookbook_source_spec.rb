require 'spec_helper'

module Berkshelf
  describe CookbookSource do
    let(:cookbook_name) { "nginx" }

    describe "#initialize" do
      subject { CookbookSource }

      context "given no location key (i.e. :git, :path, :site)" do
        let(:source) { subject.new(cookbook_name) }

        it "uses a default SiteLocation pointing to the opscode community api" do
          source.location.api_uri.should eql(subject::SiteLocation::OPSCODE_COMMUNITY_API)
        end
      end

      context "given no value for constraint" do
        let(:source) { subject.new(cookbook_name) }

        it "returns a wildcard match for any version" do
          source.version_constraint.to_s.should eql(">= 0.0.0")
        end
      end

      context "given a value for constraint" do
        let(:source) { subject.new(cookbook_name, "~> 1.0.84") }

        it "returns a Solve::Constraint for the given version for version_constraint" do
          source.version_constraint.to_s.should eql("~> 1.0.84")
        end
      end

      context "given a location key :git" do
        let(:url) { "git://url_to_git" }
        let(:source) { subject.new(cookbook_name, :git => url) }

        it "initializes a GitLocation for location" do
          source.location.should be_a(subject::GitLocation)
        end

        it "points to the given Git URL" do
          source.location.uri.should eql(url)
        end
      end

      context "given a location key :path" do
        context "given a value for path that contains a cookbook" do
          let(:path) { fixtures_path.join("cookbooks", "example_cookbook").to_s }

          it "initializes a PathLocation for location" do
            subject.new(cookbook_name, path: path).location.should be_a(subject::PathLocation)
          end

          it "points to the specified path" do
            subject.new(cookbook_name, path: path).location.path.should eql(path)
          end
        end

        context "given a value for path that does not contain a cookbook" do
          let(:path) { "/does/not/exist" }

          it "rasies Berkshelf::CookbookNotFound" do
            lambda {
              subject.new(cookbook_name, path: path)
            }.should raise_error(Berkshelf::CookbookNotFound)
          end
        end
      end

      context "given a location key :site" do
        let(:url) { "http://path_to_api/v1" }
        let(:source) { subject.new(cookbook_name, :site => url) }

        it "initializes a SiteLocation for location" do
          source.location.should be_a(subject::SiteLocation)
        end

        it "points to the specified URI" do
          source.location.api_uri.should eql(url)
        end
      end

      context "given multiple location options" do
        it "raises with an ArgumentError" do
          lambda {
            subject.new(cookbook_name, :site => "something", :git => "something")
          }.should raise_error(ArgumentError)
        end
      end

      context "given a group option containing a single group" do
        let(:group) { :production }
        let(:source) { subject.new(cookbook_name, :group => group) }

        it "assigns the single group to the groups attribute" do
          source.groups.should include(group)
        end
      end

      context "given a group option containing an array of groups" do
        let(:groups) { [ :development, :test ] }
        let(:source) { subject.new(cookbook_name, :group => groups) }

        it "assigns all the groups to the group attribute" do
          source.groups.should eql(groups)
        end
      end

      context "given no group option" do
        let(:source) { subject.new(cookbook_name) }

        it "should have the default group assigned" do
          source.groups.should include(:default)
        end
      end
    end

    subject { CookbookSource.new(cookbook_name) }

    describe '#add_group' do
      it "should store strings as symbols" do
        subject.add_group "foo"
        subject.groups.should == [:default, :foo]
      end

      it "should not store duplicate groups" do
        subject.add_group "bar"
        subject.add_group "bar"
        subject.add_group :bar
        subject.groups.should == [:default, :bar]
      end

      it "should add multiple groups" do
        subject.add_group "baz", "quux"
        subject.groups.should == [:default, :baz, :quux]
      end

      it "should handle multiple groups as an array" do
        subject.add_group ["baz", "quux"]
        subject.groups.should == [:default, :baz, :quux]
      end
    end

    describe "#download" do
      context "when download is successful" do
        it "sets a CachedCookbook to the cached_cookbook attr" do
          subject.download(tmp_path)

          subject.cached_cookbook.should be_a(Berkshelf::CachedCookbook)
        end

        it "returns an array containing the symbol :ok and the local_path" do
          result = subject.download(tmp_path)

          result.should be_a(Array)
          result[0].should eql(:ok)
          result[1].should eql(subject.cached_cookbook)
        end
      end

      context "when the download fails" do
        let(:bad_cb_name) { "NOWAYTHISEXISTS" }
        subject { CookbookSource.new(bad_cb_name) }

        it "returns an array containing the symbol :error and the error message" do
          result = subject.download(tmp_path)

          result.should be_a(Array)
          result[0].should eql(:error)
          result[1].should eql("Cookbook '#{bad_cb_name}' not found at site: 'http://cookbooks.opscode.com/api/v1/cookbooks'")
        end
      end
    end

    describe "#downloaded?" do
      subject{ CookbookSource.new("nginx", ">= 1.0.1") }

      it "delegates the message ':downloaded?' to the location" do
        subject.location.should_receive(:downloaded?)
        subject.downloaded?
      end
    end
  end
end
