# Farm to Fork site builder

A server that builds the Farm to Fork Market's site
from jekyll sources in a GitHub repository, and pushes
it to fatcow.

## Installing on heroku

```
$ heroku create farm-to-fork-publisher
$ heroku config:add BUILDPACK_URL=https://github.com/ddollar/heroku-buildpack-multi.git
$ git push heroku HEAD:master
$ heroku config:add ACCESS_KEY=`ruby -rsecurerandom -e "puts SecureRandom.hex(20)"`
$ heroku config:add FTP_HOST=ftp.farmtoforkmarket.com
$ heroku config:add FTP_USER=user
$ heroku config:add FTP_PASS=pass
```

## Setting up the hook

On the [hooks](https://github.com/farmingengineers/f2f/settings/hooks) page,
add `http://farm-to-fork-publisher.herokuapp.com/hooks/jekyll/<token>/gh-pages`
as a WebHook URL.
