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

  describe Ridley::Git::Repository do

    it "should accept a git repo" do
      repo = Ridley::Git::Repository.new(git)
    end

    it "should be able to read a simple commit" do

      commit do
        file "metadata.rb", <<'METADATA'.strip
name "foo"
maintainer "foo"
version "0.1.0"
METADATA
      end

      repo = Ridley::Git::Repository.new(git)
      cb = repo['HEAD']
      cb.name.should == 'foo-0.1.0'
      cb.instance_variable_get(:@manifest).should == {
        "attributes" => [],
        "definitions" =>[],
        "files"      => [],
        "libraries"  => [],
        "providers"  => [],
        "recipes"    => [],
        "resources"  => [], 
        "root_files" => [{
          :name => 'metadata.rb',
          :path => 'metadata.rb',
          :checksum => '05587ed842269dad12f93d8d67a1c045',
          :specifity => 'default'
        }],
        "templates" => []
      }

    end

  end

end
