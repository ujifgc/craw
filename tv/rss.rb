#!/usr/bin/ruby1.9.1
#coding:utf-8

require 'zlib'
require 'awesome_print'
require 'nokogiri'
require 'patron'
require 'fileutils'

RSS = ARGV[0]
AUTOLOAD_DIR = ARGV[1]
HOST = "http://www.torrentday.com/"

XML_CACHE = 'rss-cache.xml'
TORRENTS_DIR = 'torrents'
REQUIRE = %W(720p)
REJECT = %W(WEB-DL UNRAR WEB)

class String
  def squeeze
    self.gsub(/ +/, ' ').strip
  end

  def match_any(regs)
    regs.each do |reg|
      return true  if self.match /^#{reg}$/i
    end
    false
  end
end

class Tget
  @@sess = nil
  @@fresh = true

  def initialize
    unless @@sess
      s = Patron::Session.new
      s.base_url = HOST
      s.headers['User-Agent'] = 'Mozilla/4.0 (X11; U; Linux x86_64; en-US; rv:1.9.1.3)'
      s.headers['Referer'] = s.base_url
      s.timeout = 15000
      @@sess = s
    end
  end

  def http_get(url)
    url = url.gsub HOST, ''
    print ".. wanna get #{url}, "
    begin
      rest
      @@sess.get url
    rescue # Patron::HostResolutionError
      rest
      @@sess.get url
    end
  end

  def rest
    if @@fresh
      @@fresh = false
      return
    end
    duration = 2+rand(4)
    print "waiting #{duration} seconds...\n"
    sleep duration
  end

  def get_list
    list = IO.read('serie-list.txt').split(/[\r\n]+/)
    xml = ''

    ftime = File.mtime(XML_CACHE)  rescue Time.new(0)
    if Time.now - ftime > 10 * 60
      resp = http_get RSS
      ap status: resp.status, size: resp.body.length

      if resp.body.length < 30
        ap "! page seems to be empty"
        return nil
      end
      if resp.status >= 400
        ap "! page does not exist"
        return nil
      end

      xml = if resp.headers["Content-Encoding"].to_s.match /gzip/i
        Zlib::GzipReader.new(StringIO.new(resp.body.to_s), :external_encoding => resp.body.encoding).read
      else
        resp.body
      end

      File.open(XML_CACHE,'w') do |f|
        f.write xml
      end
    else
      ap 'using cached rss'
      File.open(XML_CACHE,'r') do |f|
        xml = f.read
      end
    end

    doc = Nokogiri::XML xml
    titles = doc.css 'item title'
    torrents = []
    downloads = []
    titles.each do |tit|
      name = tit.content.squeeze
      tags = name.match( /^(.*)[\. ]s(\d+)e(\d+)[\. -](.*)$/i ) || name.match( /^(.*)[\. ](\d+)x(\d+)[\. ](.*)$/i ) || name.match( /^(.*)[\. ](\d)(\d\d)[\. ](.*)$/i )
      torrent = { full: name,
                  link: tit.parent.css('link').first.content.squeeze,
                  title: tags && tags[1] }
      ok = true
      REQUIRE.each do |req|
        ok = false  unless torrent[:full].match /#{req}/i
      end
      REJECT.each do |rej|
        ok = false  if torrent[:full].match /#{rej}/i
      end
      ok = false  unless torrent[:title]
      if ok
        torrents << torrent
        downloads << torrent  if torrent[:title].match_any list
      end
    end
    downloads.each do |dl|
      FileUtils.mkpath TORRENTS_DIR
      name = dl[:link].partition('?')[0].rpartition('/')[2]
      path = File.join TORRENTS_DIR, name
      if File.exists? path
        ap "! already got #{name}"
      else
        resp = http_get dl[:link]
        print "\n"
        data = if resp.headers["Content-Encoding"].to_s.match /gzip/i
          Zlib::GzipReader.new(StringIO.new(resp.body.to_s), :external_encoding => resp.body.encoding).read
        else
          resp.body
        end
        File.open path, 'wb' do |f|
          f.write data
        end
        FileUtils.cp( path, AUTOLOAD_DIR )
      end

    end
  end
end

tget = Tget.new
tget.get_list
