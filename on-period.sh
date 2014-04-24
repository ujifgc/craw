#!/bin/sh

cd `dirname $0`/tv

WATCH_PATH=/mnt/u/transmission/.load
RSS_URL="torrents/rss?download;l7;u=KEY;tp=SECRET"

echo Invoke script at `date` >> logs/on-period.log

/usr/bin/env ruby rss.rb $RSS_URL $WATCH_PATH >> logs/rss.log 2>> logs/rss-error.log
