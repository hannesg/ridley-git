ridley-git
=================

Use ridley cookbooks directly from a git repository.

Usage
--------------------

At your own risk! I had to issue a pull request to make it work.

    # create a git repo containing a cookbook
    repo = Ridley::Git::Repository.new('path/to/git')
    cookbook = repo['HEAD'] #=> Ridley::Git::Cookbook, ready for upload!
    
    # now comes the standard ridley process for uploading:
    client = Ridley.new # your config here
    checksums = cookbook.checksums.dup
    sb = client.sandbox.create(checksums.keys)
    sb.upload(checksums)
    sb.commit
    client.connection.put("cookbooks/#{cookbook.cookbook_name}/#{cookbook.version}", cookbook.to_json)

Facts
----------------------

  - Works with bare and checked-out repositories
  - Caches checksums; if you crawl cookbook history, you'll feel the difference
  - Doesn't need a checkout for uploading
