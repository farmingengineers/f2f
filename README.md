# [Farm to Fork Market](http://www.farmtoforkmarket.org/)

To try this locally, you need ruby.

```
$ bundle --path .bundle --binstubs
$ _script/server
```

Open http://localhost:4004/

## Adding a newsletter

1. Open it in gmail.
2. Pick "Show original" from the message menu.
3. When the original opens, save it in the `_raw` directory of this repository. Name it "YYYY-MM-DD-subject-words.txt". For example: `2014-05-01-summer-market-begins.txt`
4. In a command prompt, run `_script/convert-newsletters.rb`.
5. `git add -v _posts images/newsletters _cc_hrefs.yml`
6. `git commit -m "Added more newsletters"`
7. `git push`

## Inspired by

* http://www.broadripplefarmersmarket.org/
* http://www.greencitymarket.org/
* http://www.hotcfarmersmarket.org/
* http://carmelfarmersmarket.com/
* http://www.indywinterfarmersmarket.org/

