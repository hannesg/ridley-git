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

    def initialize(repo, options = {})
      @git = repo
      @tree_builder = Rugged::Tree::Builder.new
      @options = options
    end

    def build(&block)
      instance_eval(&block)
      write!
    end

    def file(name, content)
      oid = @git.write(content.to_s, :blob)
      @tree_builder << { :type => :blob, :name => name, :oid => oid, :filemode => 0100644 }
    end

    def write!
      Rugged::Commit.create(
        @git,
        { :tree => @tree_builder.write(@git),
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

end
