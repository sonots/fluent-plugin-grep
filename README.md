# fluent-plugin-grep [![Build Status](https://secure.travis-ci.org/sonots/fluent-plugin-grep.png?branch=master)](http://travis-ci.org/sonots/fluent-plugin-grep) [![Dependency Status](https://gemnasium.com/sonots/fluent-plugin-grep.png)](https://gemnasium.com/sonots/fluent-plugin-grep) [![Coverage Status](https://coveralls.io/repos/sonots/fluent-plugin-grep/badge.png?branch=master)](https://coveralls.io/r/sonots/fluent-plugin-grep)

Fluentd plugin to grep messages.

## Configuration

    <match foo.bar.**>
      type grep
      input_key message
      regexp WARN
      exclude favicon.ico
      add_tag_prefix greped
    </source>

Assuming following inputs are coming:

    foo.bar: {"foo":"bar","message":"2013/01/13T07:02:11.124202 INFO GET /ping"}
    foo.bar: {"foo":"bar","message":"2013/01/13T07:02:13.232645 WARN POST /auth"}
    foo.bar: {"foo":"bar","message":"2013/01/13T07:02:21.542145 WARN GET /favicon.ico"}
    foo.bar: {"foo":"bar","message":"2013/01/13T07:02:43.632145 WARN POST /login"}

then output bocomes as belows (like, | grep WARN | grep -v favicon.ico):

    greped.foo.bar: {"foo":"bar","message":"2013/01/13T07:02:13.232645 WARN POST /auth"}
    greped.foo.bar: {"foo":"bar","message":"2013/01/13T07:02:43.632145 WARN POST /login"}

## Parameters

- input_key

    The target field key to grep out

- regexp

    The filtering regular expression

- exclude

    The excluding regular expression like grep -v

- tag

    The output tag name

- add_tag_prefix

    Add tag prefix for output message

- remove_tag_prefix

    Remove tag prefix for output message

- replace_invalid_sequence

    Replace invalid byte sequence in UTF-8 with '?' character if `true`

## ChangeLog

See [CHANGELOG.md](CHANGELOG.md) for details.

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new [Pull Request](../../pull/new/master)

## Copyright

Copyright (c) 2013 Naotoshi SEO. See [LICENSE](LICENSE) for details.

