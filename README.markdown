# MagicScan

* http://example.com

## Description

It's a thing that scans magic cards.

Right now, to get this working, you need to do this:

1. download all the cards from gatherer (it took about 40min on my machine)

```
$ bundle install
$ rake download
```

2. load the cards in to a sqlite3 database

```
$ rake categorize
```

3. Run the server

```
$ bundle exec bin/rails runner pic_and_crop.rb public
```

You should be able to hit http://localhost:8000 and scan cards

## Examples

no

## Dependencies

* no

## Current Problems

It doesn't support multiple variations on cards (for example land cards).  The
downloader needs to be fixed to download different variations.

This is a WIP, please don't hassle me!

## License

Copyright 2013 Aaron Patterson, et al.

Permission is hereby granted, free of charge, to any person obtaining
a copy of this software and associated documentation files (the
'Software'), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to
the following conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED 'AS IS', WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

