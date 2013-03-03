require 'ridley'
require 'ridley/chef/cookbook'
require 'ridley/chef/digester'
require 'rugged'
module Ridley::Git

  class Cache < Hash

    def initialize(git)
      @git = git
      super(){|hsh,key| hsh[key] = Digest::MD5.hexdigest(git.lookup(key).content) }
    end

  end

  class Cookbook < Ridley::Chef::Cookbook

    def initialize(git, tree, options = {})
      @git = git
      @tree = tree
      @cache = options.fetch(:cache){ Cache.new(@git) }
      @checksums = {}
      object = git_lookup('metadata.rb')
      meta = Ridley::Chef::Cookbook::Metadata.new
      meta.instance_eval(object.text,'metadata.rb',1)
      super(meta.name,'', meta)
    end

  private

    attr :git, :tree, :cache

    def git_lookup(name)
      @git.lookup(tree[name][:oid])
    end

    def git_checksum(oid)
      cache[oid]
    end

    def git_metadata(category, path, blob)
      {
        :name => blob[:name],
        :path => path.to_s,
        :checksum => git_checksum(blob[:oid]),
        :specifity => file_specificity(category, path)
      }
    end

    def git_glob(glob, *opts, &block)
      return to_enum(:git_glob, glob, *opts) unless block
      git_glob2(path, tree, glob.to_s, *opts, &block)
    end

    def git_glob2(path, tree, glob, *opts, &block)
      tree.each do |entry|
        name = path.join(entry[:name])
        yield name, entry if File.fnmatch?(glob,name.to_s,*opts)
        git_glob2(name, git.lookup(entry[:oid]), glob, *opts, &block) if entry[:type] == :tree
      end
    end

    def load_root
      [].tap do |files|
        git_glob(path.join('*'), File::FNM_DOTMATCH).each do |file, entry|
          next if entry[:type] == :tree
          @files << file
          @manifest[:root_files] << git_metadata(:root_files, file, entry)
        end
      end
    end

    def load_recursively(category, category_dir, glob)
      [].tap do |files|
        file_spec = path.join(category_dir, '**', glob)
        git_glob(file_spec, File::FNM_DOTMATCH).each do |file, entry|
          next if entry[:type] == :tree
          @files << file
          @manifest[category] << git_metadata(category, file, entry)
        end
      end
    end

    def load_shallow(category, *path_glob)
      [].tap do |files|
        git_glob(path.join(*path_glob)).each do |file, entry|
          @files << file
          @manifest[category] << git_metadata(category, file, entry)
        end
      end
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

    def []( name )
      ref = Rugged::Reference.lookup(git, name)
      Cookbook.new(git, git.lookup(ref.resolve.target).tree, :cache => cache)
    end

  private

    attr :cache

  end


end
