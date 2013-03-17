require 'borx'
class Ridley::Git::Cookbook < Ridley::Chef::Cookbook

  Utils = Ridley::Git::Utils

  class Environment < Borx::Environment

    include Borx::Environment::GetSetVariable
    include Borx::Environment::CallMethod

    def call_method(binding, receiver, method, *args, &block)
      if receiver == IO && method == 'read'
        path = File.expand_path(args.first, '/')
        blob = Utils.traverse(@git, @tree, path)
        if blob.nil?
          raise Error::ENOENT, "No such file or directory - #{path}"
        end
        return blob.content
      end
      return super
    end

    def initialize(git, tree)
      @git = git
      @tree = tree
    end

  end

  def initialize(git, tree, options = {})
    @git = git
    @tree = tree
    @cache = options.fetch(:cache){ Cache.new(@git) }
    @checksums = {}
    object = git_lookup('metadata.rb')
    meta = Ridley::Chef::Cookbook::Metadata.new
    env = Environment.new(git, tree)
    env.eval(object.text, :self => meta, :file => '/metadata.rb' )
    super(meta.name,'', meta)
  end

  def files
    actually_load_files
    super
  end

  def checksums
    actually_load_files
    return @checksums
  end

  def tree_id
    return tree.oid
  end

private

  # Dummy method. The file list will be loaded lazily
  def load_files
  end

  def actually_load_files
    return if @files_loaded
    Ridley::Chef::Cookbook.instance_method(:load_files).bind(self).call
    @files_loaded = true
  end
  def manifest
    actually_load_files
    super
  end

  attr :git, :tree, :cache

  def git_lookup(name)
    @git.lookup(tree[name][:oid])
  end

  def git_checksum(oid)
    cache[oid]
  end

  def git_io(oid)
    Ridley::Git::BlobIO.new(@git.lookup(oid))
  end

  def git_metadata(category, path, blob)
    {
      :name => blob[:name],
      :path => path.to_s,
      :checksum => git_checksum(blob[:oid]),
      :specifity => file_specificity(category, path)
    }
  end

  def tree?(entry)
    git.lookup(entry[:oid]).kind_of? Rugged::Tree
  end

  def git_glob(glob, *opts, &block)
    return to_enum(:git_glob, glob, *opts) unless block
    git_glob2(path, tree, glob.to_s, *opts, &block)
  end

  def git_glob2(path, tree, glob, *opts, &block)
    tree.each do |entry|
      name = path.join(entry[:name])
      yield name, entry if File.fnmatch?(glob,name.to_s,*opts)
      git_glob2(name, git.lookup(entry[:oid]), glob, *opts, &block) if tree? entry
    end
  end

  def push_metadata(category, file, entry)
    meta = git_metadata(category, file, entry)
    @checksums[meta[:checksum]] = git_io(entry[:oid])
    @files << file
    @manifest[category] << meta
  end

  def load_root
    tree.each do |entry|
      next if tree? entry
      push_metadata(:root_files, entry[:name], entry)
    end
  end

  def load_recursively(category, category_dir, glob)
    file_spec = path.join(category_dir, '**', glob)
    git_glob(file_spec, File::FNM_DOTMATCH).each do |file, entry|
      next if tree? entry
      push_metadata(category, file, entry)
    end
  end

  def load_shallow(category, *path_glob)
    git_glob(path.join(*path_glob)).each do |file, entry|
      next if tree? entry
      push_metadata(category, file, entry)
    end
  end

end
