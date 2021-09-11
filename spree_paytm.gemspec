# frozen_string_literal: true

lib = File.expand_path('lib', __dir__)
$LOAD_PATH.unshift lib unless $LOAD_PATH.include?(lib)

require 'spree_paytm/version'
Gem::Specification.new do |s|
  s.platform              = Gem::Platform::RUBY
  s.name                  = 'spree_paytm'
  s.version               = SpreePaytm::VERSION
  s.summary               = 'Paytm integration into spree application.'
  s.description           = s.summary
  s.required_ruby_version = '>= 2.1.0'

  s.author    = 'Monika Khatri'
  s.email     = 'monika.khatri.d@gmail.com'
  s.homepage  = 'https://github.com/monika-khatri/spree-paytm'

  s.files        = `git ls-files`.split("\n")
  s.test_files   = `git ls-files -- spec/*`.split("\n")
  s.require_path = 'lib'
  s.requirements << 'none'

  s.add_dependency 'spree_core', '>= 3.7.0'
end
