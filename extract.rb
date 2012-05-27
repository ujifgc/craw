#!/usr/bin/ruby1.9.1
require 'logger'
require 'time'

OUTPUT = "V:/temp/_WATCH!"

log = Logger.new "#{ENV['HOME']}/extract.log"
log << "\n\n================ " + Time.new.strftime("%Y-%m-%d %H:%M:%S") + " =================\n"

dir = ARGV[1].gsub /\\+/, '/'

files = Dir.glob dir + '/**/*.rar'

files.each do |file|
  log.info "found file #{file}"
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
      log.info "detected movie #{movie.strip}"

      oldname = File.join(OUTPUT, @file[:name])
      if File.exists? oldname
        oldsize = File.size oldname
        good = false  if oldsize.to_i == @file[:size].to_i
      end
      if good
        log.info "invoking 7z extractor, new size: #{@file[:size]}"
        puts "invoking 7z extractor, new size: #{@file[:size]}"
        puts "7z e #{file} -aoa -o#{OUTPUT}"
        log << `7z e #{file} -aoa -o#{OUTPUT}`
      else
        log.info "skipping existing file size: #{oldsize}"
      end
    end
    log << "\n"

  end
end
