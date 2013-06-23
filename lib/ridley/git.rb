require 'ridley'
require 'ridley/chef/cookbook'
require 'ridley/chef/digester'
require 'multi_git'

module Ridley::Git

  class Cache < Hash

    def initialize(git)
      @git = git
      super(){|hsh,key| hsh[key] = Digest::MD5.hexdigest(git.read(key).content) }
    end

  end

  class Repository

    include Enumerable

    attr :git

    def initialize(git_repository, options = {})
      if git_repository.kind_of? String
        @git = MultiGit.open(git_repository)
      elsif git_repository.kind_of? MultiGit::Repository
        @git = git_repository
      else
        raise ArgumentException, "Cannot convert #{git_repository.inspect} into a Rugged::Repository"
      end
      @path = options.fetch(:path, '')
      @cache = Cache.new(@git)
    end

    def []( name, path = '/' )
      rev = git.read(name)
      Cookbook.new(git, rev, path , :cache => cache)
    end

    def each(from, path = '/' )
      commit = git.read(from)
      loop do
        yield Cookbook.new(git, commit, path, :cache => cache )
        commit = commit.parents[0]
        return if commit.nil?
      end
    end

  private

    attr :cache

  end

end

require 'ridley/git/cookbook'
