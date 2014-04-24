#!/bin/bash

cd `dirname $0`/tv
source ../craw.conf

echo Invoke script at `date` >> logs/on-period.log

/usr/bin/env ruby rss.rb $RSS_URL $WATCH_PATH >> logs/rss.log 2>> logs/rss-error.log
