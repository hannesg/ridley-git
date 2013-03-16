ridley-git
=================

[![Build Status](https://travis-ci.org/hannesg/ridley-git.png?branch=master)](https://travis-ci.org/hannesg/ridley-git)
[![Coverage Status](https://coveralls.io/repos/hannesg/ridley-git/badge.png?branch=master)](https://coveralls.io/r/hannesg/ridley-git)

Use ridley cookbooks directly from a git repository.

Usage
--------------------

At your own risk!

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
  - Handles IO.read from metadata.rb correctly ( but may fail on other things )

License
-------------------

Copyright (C) 2013 Hannes Georg

Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
the Software, and to permit persons to whom the Software is furnished to do so,
subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
