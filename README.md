# git_tagger

A Ruby Gem designed to expedite: the git tagging procedure and updating a changelog

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'git_tagger'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install git_tagger

## Usage

Add the following code to the project's Rakefile:

    git_tagger = Gem::Specification.find_by_name "git_tagger"
    load "#{git_tagger.gem_dir}/lib/tasks/deploy.rake"

## Contributing

1. Fork it ( https://github.com/eschlange/git_tagger/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
