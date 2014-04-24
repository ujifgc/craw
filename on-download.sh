#!/bin/bash

cd `dirname $0`/tv
source ../craw.conf

echo Invoke script for $DOWNLAD_PATH at `date` >> logs/on-download.log

/usr/bin/env ruby extract.rb $DOWNLOAD_PATH $EXTRACT_PATH $ARCHIVE_PATH >> logs/extract.log 2>> logs/extract-error.log
/usr/bin/env ruby subtitle.rb $EXTRACT_PATH >> logs/subtitle.log 2>> logs/subtitle-error.log
