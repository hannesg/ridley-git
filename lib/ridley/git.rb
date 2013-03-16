require 'ridley'
require 'ridley/chef/cookbook'
require 'ridley/chef/digester'
require 'rugged'

module Ridley::Git

  module Utils

    def traverse(git, tree, path)
      path.split('/').inject(tree) do |tree, elem|
        case(elem)
        when '', '.' then tree
        else
          entry = tree[elem]
          raise "Missing path #{elem}" unless entry
          git.lookup(entry[:oid])
        end
      end
    end

    extend self

  end

  class Cache < Hash

    def initialize(git)
      @git = git
      super(){|hsh,key| hsh[key] = Digest::MD5.hexdigest(git.lookup(key).content) }
    end

  end

  class BlobIO < IO

    def initialize(git_blob)
      @blob = git_blob
    end

    def read
      @blob.content
    end

  end

  class Repository

    attr :git

    def initialize(git_repository, options = {})
      if git_repository.kind_of? String
        @git = Rugged::Repository.discover(git_repository)
      elsif git_repository.kind_of? Rugged::Repository
        @git = git_repository
      else
        raise ArgumentException, "Cannot convert #{git_repository.inspect} into a Rugged::Repository"
      end
      @path = options.fetch(:path, '')
      @cache = Cache.new(@git)
    end

    def []( name, path = '/' )
      ref = Rugged::Reference.lookup(git, name)
      base = git.lookup(ref.resolve.target).tree
      Cookbook.new(git, Utils.traverse(git, base, path) , :cache => cache)
    end

  private

    attr :cache

  end

end

require 'ridley/git/cookbook'
