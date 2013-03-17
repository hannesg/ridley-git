require 'fileutils'
require 'tmpdir'
describe Ridley::Git do

  after(:each) do
    FileUtils.rm_rf(@tempdir) if @tempdir
  end

  let(:tempdir){
    Dir.mktmpdir('ridley-git-')
  }

  let(:git){
    Rugged::Repository.init_at(tempdir, true)
  }

  class CommitBuilder

    def tree
      return @tree_builder.write(@git)
    end

    def initialize(repo, options = {})
      @git = repo
      @tree_builder = Rugged::Tree::Builder.new
      @options = options
    end

    def build(&block)
      instance_eval(&block)
      write!
    end

    def dir(name, &block)
      b = CommitBuilder.new(@git)
      b.instance_eval(&block)
      @tree_builder << { :type => :tree, :name => name, :oid => b.tree, :filemode => 0100644 }
    end

    def file(name, content)
      oid = @git.write(content.to_s, :blob)
      @tree_builder << { :type => :blob, :name => name, :oid => oid, :filemode => 0100644 }
    end

    def write!
      Rugged::Commit.create(
        @git,
        { :tree => tree,
          :author => { :email => 'test@ridley.git', :name => 'Ridley Git', :time => Time.now },
          :committer => { :email => 'test@ridley.git', :name => 'Ridley Git', :time => Time.now },
          :message => "Test",
          :parents => @git.empty? ? [] : [ @git.head.target ].compact,
          :update_ref => 'HEAD'
        }.merge(@options)
      )
    end

  end

  def commit(&block)
    CommitBuilder.new(git).build(&block)
  end

  def empty_manifest
    {
      "attributes" => [],
      "definitions" =>[],
      "files"      => [],
      "libraries"  => [],
      "providers"  => [],
      "recipes"    => [],
      "resources"  => [], 
      "root_files" => [],
      "templates" => []
    }
  end

  describe Ridley::Git::Repository do

    it "should accept a git repo" do
      repo = Ridley::Git::Repository.new(git)
    end


    describe "with the smallest possible cookbook" do

      before(:each) do
        commit do
           file "metadata.rb", <<'METADATA'.strip
name "foo"
version "0.1.0"
METADATA
        end
      end

      it "reads name and version correctly" do
        repo = Ridley::Git::Repository.new(git)
        cb = repo['HEAD']
        cb.name.should == 'foo-0.1.0'
      end

      it "calculates the manifest correctly" do
        repo = Ridley::Git::Repository.new(git)
        cb = repo['HEAD']
        # manifest is private
        cb.send(:manifest).should == empty_manifest.merge(
          "root_files" => [{
            :name => 'metadata.rb',
            :path => 'metadata.rb',
            :checksum => 'f6f3647fecaa0e09308799eee70d30c1',
            :specifity => 'default'
          }]
        )
      end

      it "calculates the checksums correctly" do
        repo = Ridley::Git::Repository.new(git)
        cb = repo['HEAD']
        checksums = cb.checksums
        checksums.should have(1).item
        checksums.keys.first.should == 'f6f3647fecaa0e09308799eee70d30c1'
        checksums.values.first.should respond_to(:read)
        checksums.values.first.read.should == <<'METADATA'.strip
name "foo"
version "0.1.0"
METADATA
      end

    end

  end

  describe "with a reasonable cookbook" do

    before(:each) do
      commit do
        file "metadata.rb", <<'METADATA'.strip
name "foo"
version "0.1.0"
long_description IO.read(File.join(File.dirname(__FILE__),'README.md'))
METADATA
        file "README.md", <<'README'.strip
# Foo
README
        dir "recipes" do
          file "default.rb", <<'RECIPE'.strip
file "foo" do
content "bar"
end
RECIPE
        end
      end
    end

    it "reads name and version correctly" do
      repo = Ridley::Git::Repository.new(git)
      cb = repo['HEAD']
      cb.name.should == 'foo-0.1.0'
    end

    it "calculates the manifest correctly" do
      repo = Ridley::Git::Repository.new(git)
      cb = repo['HEAD']
      # manifest is private
      cb.send(:manifest).should == empty_manifest.merge(
        "recipes" => [
          {:name=>"default.rb", :path=>"recipes/default.rb", :checksum=>'632c42688fc390f123d2980389d0f4b1', :specifity=>"default"}
        ],
        "root_files" => [
          {:name=>"README.md", :path=>"README.md", :checksum=>"b4405bcd06a4da2027c594f21e69f32e", :specifity=>"default"},
          {:name=>"metadata.rb", :path=>"metadata.rb", :checksum=>"d7fb90833b4458b5ea33fbf2e4847068", :specifity=>"default"}
        ]
      )
    end

    it "calculates the checksums correctly" do
      repo = Ridley::Git::Repository.new(git)
      cb = repo['HEAD']
      checksums = cb.checksums
      checksums.should have(3).item
      checksums.keys.sort.should == [ '632c42688fc390f123d2980389d0f4b1','b4405bcd06a4da2027c594f21e69f32e', 'd7fb90833b4458b5ea33fbf2e4847068' ]
    end

    it "calculates the  contents correctly" do
      repo = Ridley::Git::Repository.new(git)
      cb = repo['HEAD']
      checksums = cb.checksums
      checksums['d7fb90833b4458b5ea33fbf2e4847068'].read.should == <<'METADATA'.strip
name "foo"
version "0.1.0"
long_description IO.read(File.join(File.dirname(__FILE__),'README.md'))
METADATA
      checksums['b4405bcd06a4da2027c594f21e69f32e'].read.should == <<'readme'.strip
# Foo
readme
      checksums['632c42688fc390f123d2980389d0f4b1'].read.should == <<'RECIPE'.strip
file "foo" do
content "bar"
end
RECIPE

    end

    it "calculates the metadata correctly" do
      repo = Ridley::Git::Repository.new(git)
      cb = repo['HEAD']
      cb.metadata.long_description.should == "# Foo"
    end

    it "eaches correctly" do
      repo = Ridley::Git::Repository.new(git)
      expect{|b| repo.each('HEAD', &b) }.to yield_with_args(Ridley::Git::Cookbook)
    end

    it "eaches correctly with an array of refs" do
      repo = Ridley::Git::Repository.new(git)
      expect{|b| repo.each(['HEAD'], &b) }.to yield_with_args(Ridley::Git::Cookbook)
    end

  end

end
