require 'borx'
class Ridley::Git::Cookbook < Ridley::Chef::Cookbook

  class Environment < Borx::Environment

    include Borx::Environment::GetSetVariable
    include Borx::Environment::CallMethod

    def call_method(binding, receiver, method, *args, &block)
      if receiver == IO && method == 'read'
        path = File.expand_path(args.first, '/')
        blob = @tree.traverse(path)
        if blob.nil?
          raise Error::ENOENT, "No such file or directory - #{path}"
        end
        return blob.content
      end
      return super
    end

    def initialize(tree)
      @tree = tree
    end

  end

  def initialize(git, commit, path, options = {})
    @git = git
    @tree = commit.tree.traverse(path)
    @cache = options.fetch(:cache){ Cache.new(@git) }
    @checksums = {}
    object = @tree['metadata.rb']
    meta = Ridley::Chef::Cookbook::Metadata.new
    env = Environment.new(tree)
    env.eval(object.content, :self => meta, :file => '/metadata.rb' )
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

  def git_metadata(category, path, blob)
    {
      :name => blob.name,
      :path => path.to_s,
      :checksum => cache[blob.oid],
      :specifity => file_specificity(category, path)
    }
  end

  def push_metadata(category, entry)
    meta = git_metadata(category, entry.path, entry)
    @checksums[meta[:checksum]] = entry.to_io
    @files << entry.path
    @manifest[category] << meta
  end

  def load_root
    tree.each do |entry|
      next if entry.kind_of? MultiGit::Directory
      push_metadata(:root_files, entry)
    end
  end

  def load_recursively(category, category_dir, glob)
    file_spec = path.join(category_dir, '**', glob).to_s
    tree.glob(file_spec, File::FNM_DOTMATCH) do |entry|
      push_metadata(category, entry)
    end
  end

  def load_shallow(category, *path_glob)
    tree.glob(path.join(*path_glob).to_s) do |entry|
      push_metadata(category, entry)
    end
  end

end
