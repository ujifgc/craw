Installation:
====

    sudo gem install awesome_print nokogiri patron
    sudo cp craw.rb /usr/bin/craw
    sudo chmod 755 /usr/bin/craw

Usage:
====

    cd /path/to/your/downloaded/series
    craw

The directory must contain standard formatted list of .mkv files. For example:

    alphas.s01e09.720p.hdtv.x264-orenji.mkv
    Breaking.Bad.S04E09.720p.HDTV.x264-IMMERSE.mkv
    Entourage.S08E08.720p.HDTV.X264-DIMENSION.mkv
    True.Blood.S04E12.720p.HDTV.X264-DIMENSION.mkv
    Warehouse.13.S03E09.720p.HDTV.X264-DIMENSION.mkv
    Weeds.S07E11.720p.HDTV.X264-DIMENSION.mkv

The output will be something like:

    alphas.s01e09.720p.hdtv.x264-orenji.srt
    Breaking.Bad.S04E09.720p.HDTV.x264-IMMERSE.srt
    Entourage.S08E08.720p.HDTV.X264-DIMENSION.srt
    True.Blood.S04E12.720p.HDTV.X264-DIMENSION.srt
    Warehouse.13.S03E09.720p.HDTV.X264-DIMENSION.srt
    Weeds.S07E11.720p.HDTV.X264-DIMENSION.srt

To www.addic7ed.com will be `2*n` http requests made: `n` to get pages of the episodes
and `n` to get actual subtitles (where n is a count of mkv files in the directory).
