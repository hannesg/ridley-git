Gem::Specification.new do |gem|
  gem.name    = 'ridley-git'
  gem.version = '0.0.1.alpha1'
  gem.date    = Time.now.strftime("%Y-%m-%d")

  gem.summary = "directly interact with git repositories in ridley"
  gem.description = "This library allows you read cookbooks directly from a git repository. There is no need to do a checkout and you can access all revisions."

  gem.authors  = ['Hannes Georg']
  gem.email    = 'hannes.georg@googlemail.com'
  gem.homepage = 'https://github.com/hannesg/ridley-git'

  # ensure the gem is built out of versioned files
  gem.files = Dir['lib/**/*'] & `git ls-files -z`.split("\0")

  gem.add_dependency "rugged", ">= 0.17.0b1"
  gem.add_dependency "borx"  , ">= 0.0.1.beta1"
  gem.add_dependency "ridley", "~> 0.8.0", ">= 0.8.4"

  gem.add_development_dependency "rspec"
  gem.add_development_dependency "simplecov"
end
