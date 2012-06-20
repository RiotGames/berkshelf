require 'spec_helper'

module KnifeCookbookDependencies
  describe Cookbookfile do
    describe "ClassMethods" do
      subject { Cookbookfile }

      let(:content) do
<<-EOF
cookbook 'ntp', '<= 1.0.0'
cookbook 'mysql'
cookbook 'nginx', '< 0.101.2'
cookbook 'ssh_known_hosts2', :git => 'https://github.com/erikh/chef-ssh_known_hosts2.git'
EOF
      end

      describe "#read" do
        it "reads the content of a Cookbookfile and adds the sources to the Shelf" do
          cbfile = subject.read(content)

          ['ntp', 'mysql', 'nginx', 'ssh_known_hosts2'].each do |name|
            cbfile.should have_source(name)
          end
        end

        it "returns an instance of Cookbookfile" do
          subject.read(content).should be_a(Cookbookfile)
        end
      end

      describe "#from_file" do
        let(:cookbook_file) { fixtures_path.join('lockfile_spec', 'with_lock', 'Cookbookfile') }

        it "reads a Cookbookfile and returns an instance Cookbookfile" do
          subject.from_file(cookbook_file).should be_a(Cookbookfile)
        end

        context "when Cookbookfile does not exist at given path" do
          let(:bad_path) { tmp_path.join("thisdoesnotexist") }

          it "raises CookbookfileNotFound" do
            lambda {
              subject.from_file(bad_path)
            }.should raise_error(CookbookfileNotFound)
          end
        end
      end

      describe "#filter_sources" do
        context "given one of the sources is a member of one of the excluded groups" do
          let(:excluded_groups) { [:nautilus, :skarner] }
          let(:source_one) { double('source_one') }
          let(:source_two) { double('source_two') }

          before(:each) do
            source_one.stub(:groups) { [:nautilus] }
            source_two.stub(:groups) { [:riven] }
            @sources = [source_one, source_two]
          end

          it "returns an array without sources that were members of the excluded groups" do
            result = subject.filter_sources(@sources, excluded_groups)

            result.should_not include(source_one)
          end

          it "does not remove sources that were not a member of the excluded groups" do
            result = subject.filter_sources(@sources, excluded_groups)

            result.should include(source_two)
          end
        end
      end
    end

    let(:source_one) { double('source_one', name: "nginx") }
    let(:source_two) { double('source_two', name: "mysql") }

    subject do
      cbf = Cookbookfile.new
      cbf.add_source(source_one)
      cbf.add_source(source_two)
      cbf
    end

    describe "#sources" do
      it "returns all CookbookSources added to the instance of Cookbookfile" do
        result = subject.sources

        result.should have(2).items
        result.should include(source_one)
        result.should include(source_two)
      end

      context "given the option :exclude" do
        it "filters the sources before returning them" do
          subject.class.should_receive(:filter_sources).with(subject.sources, :nautilus)

          subject.sources(exclude: :nautilus)
        end
      end
    end

    describe "#groups" do
      before(:each) do
        source_one.stub(:groups) { [:nautilus, :skarner] }
        source_two.stub(:groups) { [:nautilus, :riven] }
      end

      it "returns a hash containing keys for every group a source is a member of" do
        subject.groups.keys.should have(3).items
        subject.groups.should have_key(:nautilus)
        subject.groups.should have_key(:skarner)
        subject.groups.should have_key(:riven)
      end

      it "returns an Array of CookbookSources who are members of the group for value" do
        subject.groups[:nautilus].should include(source_one)
        subject.groups[:nautilus].should include(source_two)
        subject.groups[:riven].should_not include(source_one)
      end
    end

    describe "#install" do
      let(:resolver) { double('resolver') }

      before(:each) do
        KCD::Resolver.stub(:new) { resolver }
      end

      it "creates a new resolver and finds a solution by calling resolve on the resolver" do
        resolver.should_receive(:resolve)
        resolver.should_receive(:sources)

        subject.install
      end

      it "writes a lockfile with the resolvers sources" do
        resolver.should_receive(:resolve)
        resolver.should_receive(:sources).and_return([source_one])
        subject.should_receive(:write_lockfile).with([source_one])

        subject.install
      end
    end
  end
end
