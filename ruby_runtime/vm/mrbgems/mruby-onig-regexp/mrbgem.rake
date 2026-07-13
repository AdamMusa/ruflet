MRuby::Gem::Specification.new('mruby-onig-regexp') do |spec|
  spec.license = 'MIT'
  spec.authors = 'mattn'
  spec.summary = 'Oniguruma/Onigmo-backed Regexp, built from the vendored onigmo sources'
  spec.add_dependency 'mruby-string-ext', core: 'mruby-string-ext'

  onigmo = "#{dir}/onigmo"
  spec.cc.include_paths << onigmo << "#{onigmo}/enc/unicode" << "#{onigmo}/enc/jis"
  spec.cc.defines << 'HAVE_ONIGMO_H'
  # src/mruby_onig_regexp.c is picked up by the default srcs glob; add the
  # vendored onigmo sources (minus the mktable generator tool).
  spec.objs += (srcs_to_objs('onigmo') + srcs_to_objs('onigmo/enc'))
               .reject { |obj| obj.include?('mktable') }
end
