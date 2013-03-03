Gem::Specification.new do |gem|
  gem.name    = 'ridley-git'
  gem.version = '0.0.1'
  gem.date    = Time.now.strftime("%Y-%m-%d")

  gem.summary = "an awesome gem"
  gem.description = "extended description"

  gem.authors  = ['Hannes Georg']
  gem.email    = 'hannes.georg@googlemail.com'
  gem.homepage = 'https://github.com/hannesg/ridley-git'

  # ensure the gem is built out of versioned files
  gem.files = Dir['{bin,lib,man,test,spec}/**/*'] & `git ls-files -z`.split("\0")

  gem.add_dependency "rugged", ">= 0.17.0b1"
  gem.add_dependency "ridley", "~> 0.8.0", ">= 0.8.1"

  gem.add_development_dependency "rspec"
end
