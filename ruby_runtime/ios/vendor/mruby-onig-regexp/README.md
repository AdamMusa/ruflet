# mruby-onig-regexp

[![Build Status](https://travis-ci.org/mattn/mruby-onig-regexp.svg)](https://travis-ci.org/mattn/mruby-onig-regexp)

## install by mrbgems
```ruby
MRuby::Build.new do |conf|

    # ... (snip) ...

    conf.gem :github => 'mattn/mruby-onig-regexp'
end
```

If libonig development files are installed on the host system, those
will be used.  Otherwise, the bundled copy will be built and used
instead.  If you want rake to **always** use the bundled library, this
can be done by calling `bundle_onigmo` in the gem declaration body:

```ruby
MRuby::Build.new do |conf|
    # ... (snip) ...

    conf.gem :github => 'mattn/mruby-onig-regexp' do
        # Force the use of the bundled copy of the lib
        self.bundle_onigmo
    end
end
```

## Example
```ruby

def matchstr(str)
  reg = Regexp.compile("abc")

  if reg =~ str then
    p "match"
  else
    p "not match"
  end
end

matchstr("abcdef") # => match
matchstr("ghijkl") # => not match
matchstr("xyzabc") # => match
```

## License

MIT

### License of Onigmo
BSD licensed.

    Onigmo (Oniguruma-mod)  --  (C) K.Takata <kentkt AT csc DOT jp>
    Oniguruma  ----   (C) K.Kosako <sndgk393 AT ybb DOT ne DOT jp>

## Author

Yasuhiro Matsumoto (a.k.a mattn)
