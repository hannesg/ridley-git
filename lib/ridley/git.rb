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

    def rev_to_oid(git, rev)
      Rugged::Reference.lookup(git, rev).resolve.target
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

    include Enumerable

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

    def each( refs, path = '/' )
      walker = Rugged::Walker.new(@git)
      case(refs)
      when String then
        walker.push(Utils.rev_to_oid(git, refs))
      when Array then
        refs.each do |r|
          walker.push(Utils.rev_to_oid(git, r))
        end
      when Range then
        walker.push( Utils.rev_to_oid(git, refs.end) )
        walker.hide( Utils.rev_to_oid(git, refs.begin) )
      end
      seen = Set.new
      walker.each do |commit|
        tree = Utils.traverse(@git, commit.tree, path)
        unless seen.include? tree
          yield self[tree]
          seen << tree
        end
      end
      return self
    end

    def []( name, path = '/' )
      base = nil
      case name
      when String then
        return self[ git.lookup(Rugged::Reference.lookup(git, name).resolve.target), path ]
      when Rugged::Commit then
        base = name.tree
      when Rugged::Tree then
        base = name
      else
        raise "Unknown arg #{name}"
      end
      Cookbook.new(git, Utils.traverse(git, base, path) , :cache => cache)
    end

  private

    attr :cache

  end

end

require 'ridley/git/cookbook'
