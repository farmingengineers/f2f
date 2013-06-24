#!/bin/bash

PARAMS="f2f gh-pages farmingengineers https://github.com/farmingengineers/f2f.git /app/tmp/farmingengineers/f2f/gh-pages/code /app/tmp/farmingengineers/f2f/gh-pages/site"
set -x
bash `dirname $0`/build.sh   $PARAMS
bash `dirname $0`/publish.sh $PARAMS
