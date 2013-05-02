# fluent-plugin-grep [![Build Status](https://secure.travis-ci.org/sonots/fluent-plugin-grep.png?branch=master)](http://travis-ci.org/sonots/fluent-plugin-grep) [![Dependency Status](https://gemnasium.com/sonots/fluent-plugin-grep.png)](https://gemnasium.com/sonots/fluent-plugin-grep) [![Coverage Status](https://coveralls.io/repos/sonots/fluent-plugin-grep/badge.png?branch=master)](https://coveralls.io/r/sonots/fluent-plugin-grep)

Fluentd plugin to grep messages.

## Configuration

Assume inputs from another plugin are as belows:

    syslog.host1: {"foo":"bar","message":"2013/01/13T07:02:11.124202 INFO GET /ping"}
    syslog.host1: {"foo":"bar","message":"2013/01/13T07:02:13.232645 WARN POST /auth"}
    syslog.host1: {"foo":"bar","message":"2013/01/13T07:02:21.542145 WARN GET /favicon.ico"}
    syslog.host1: {"foo":"bar","message":"2013/01/13T07:02:43.632145 WARN POST /login"}

An example of grep configuration:

    <match syslog.**>
      type grep
      input_key message
      regexp WARN
      exclude favicon.ico
      add_tag_prefix grep
    </source>

Then, output bocomes as belows:

    grep.syslog.host1: {"foo":"bar","message":"2013/01/13T07:02:13.232645 WARN POST /auth"}
    grep.syslog.host1: {"foo":"bar","message":"2013/01/13T07:02:43.632145 WARN POST /login"}

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

