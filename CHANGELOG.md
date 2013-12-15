## 0.3.1 (2013/12/16)

Changes:

- Make it possible that regexp to contain a heading space on `regexpN` and `excludeN` option.

## 0.3.0 (2013/12/15)

Features:

- Add `regexpN` and `excludeN` option. `input_key`, `regexp`, and `exclude` options are now obsolete.

## 0.2.1 (2013/12/12)

Features:

- Allow to use `remove_tag_prefix` option alone

## 0.2.0 (2013/11/30)

Features:

- Add `remove_tag_prefix` option

## 0.1.1 (2013/11/02)

Changes:

- Revert String#scrub because `string-scrub` gem is only for >= ruby 2.0.

## 0.1.0 (2013/11/02)

Changes:

- Use String#scrub

## 0.0.3 (2013/05/14)

Features:

- Support to grep non-string jsonable values (such as integer, array) by #to_s. 

Changes:

- Default tag prefix from `grep` to `greped`. 

## 0.0.2 (2013/05/02)

Features:

- Add `replace_invalid_sequence` option

## 0.0.1 (2013/05/02)

First version
