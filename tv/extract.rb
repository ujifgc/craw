#!/usr/bin/env ruby
require 'time'

INPUT, OUTPUT, ARCHIVE = ARGV

ARCHIVE_GLOB = '*.rar'
MOVIE_EXTNAMES = /(?:\.mkv|\.mp4|\.avi|\.m4v)$/i

raise ArgumentError, 'No directory provided'  unless INPUT.kind_of? String

puts  "\n================ " + Time.new.strftime("%Y-%m-%d %H:%M:%S") + " ================="

files = Dir.glob File.join(INPUT, ARCHIVE_GLOB)
puts 'no files found'  unless files.any?

files.each do |file|
  puts "found file #{file}"
  listing = `7z l #{file}`

  listing.lines.grep(MOVIE_EXTNAMES).each do |movie|
    tags = movie.split /\s+/
    filename = tags[-1].strip
    filesize = tags[-3].strip

    puts "detected movie #{movie.strip}"

    oldsize = 0
    oldname = ''
    skip = nil
    [OUTPUT, ARCHIVE].each do |dirname|
      pathname = File.join(dirname, filename)
      if File.file? pathname
        oldname = pathname
        oldsize = File.size pathname
        skip = true if oldsize.to_i == filesize.to_i
        break
      end
    end

    if skip
      puts "skipping existing file size: #{oldsize} @ #{oldname}"
      next
    end

    puts "invoking 7z extractor, new size: #{filesize}"
    puts "7z e #{file} -aoa -o#{OUTPUT}"
    puts `7z e #{file} -aoa -o#{OUTPUT}`
  end
end
