#!/usr/bin/env ruby
require 'awesome_print'
require 'time'

INPUT = ARGV[0]
OUTPUT = ARGV[1]
ARCHIVE = ARGV[2]

raise ArgumentError, 'No directory provided'  unless INPUT.kind_of? String

ap  "================ " + Time.new.strftime("%Y-%m-%d %H:%M:%S") + " ================="

files = Dir.glob INPUT + '/*.rar'
ap 'no files found'  unless files.any?

files.each do |file|
  ap "found file #{file}"
  inside = `7z l #{file}`
  movies = inside.lines.grep /\.mkv|\.mp4|\.avi|\.m4v$/
  good = false
  @file = {}
  movies.each do |movie|
    tags = movie.split( /\s+/ )
    @file = {
      :name => tags[-1].strip,
      :size => tags[-3].strip,
    }
    good = @file[:name].match( /^(.*)\.s(\d+)e(\d+)(?:\-?e\d+)?\.(.*)$/i ) || @file[:name].match( /^(.*)\.(\d+)x(\d+)?\.(.*)$/i ) || @file[:name].match( /^(.*)\.(\d+)?\.(.*)$/i )

    if good
      ap "detected movie #{movie.strip}"

      oldsize = 0
      oldname = ''
      [OUTPUT, ARCHIVE].each do |dirname|
        pathname = File.join(dirname, @file[:name])
        if File.exists? pathname
          oldname = pathname
          oldsize = File.size pathname
          good = false  if oldsize.to_i == @file[:size].to_i
          break
        end
      end

      if good
        ap "invoking 7z extractor, new size: #{@file[:size]}"
        ap "7z e #{file} -aoa -o#{OUTPUT}"
        ap `7z e #{file} -aoa -o#{OUTPUT}`
      else
        ap "skipping existing file size: #{oldsize} @ #{oldname}"
      end
    end

  end
end
