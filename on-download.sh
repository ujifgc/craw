#!/bin/sh

cd `dirname $0`/tv

DOWNLOAD_PATH=$TR_TORRENT_DIR/$TR_TORRENT_NAME
EXTRACT_PATH=/mnt/u/temp/_WATCH!
ARCHIVE_PATH=/mnt/u/tv

echo Invoke script for $DOWNLAD_PATH at `date` >> logs/on-download.log

/usr/bin/env ruby extract.rb $DOWNLOAD_PATH $EXTRACT_PATH $ARCHIVE_PATH >> logs/extract.log 2>> logs/extract-error.log
/usr/bin/env ruby subtitle.rb $EXTRACT_PATH >> logs/subtitle.log 2>> logs/subtitle-error.log
