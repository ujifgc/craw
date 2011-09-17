#!/usr/bin/ruby1.9.1
#coding:utf-8

require 'awesome_print'
require 'nokogiri'
require 'patron'

LANGS = %w(english russian)

LIKE_FLAGS = [ /720p?/i ]
NEED_FLAGS = [ /.*/i ]
DROP_FLAGS = [ /web.?dl/i, /dvd.?rip/i ]

class String
  alias_method :old_strip, :strip
  def strip
    self.gsub(/ +/, ' ').old_strip
  end

  def match_any(regs)
    regs.each do |reg|
      return true  if self.match reg
    end
    false
  end
end

class Craw
  @@sess = nil
  @@rested = true

  def initialize
    unless @@sess
      s = Patron::Session.new
      s.base_url = "http://www.addic7ed.com/"
      s.headers['User-Agent'] = 'Mozilla/5.0 (X11; U; Linux x86_64; en-US; rv:1.9.1.3)'
      s.headers['Referer'] = s.base_url
      @@sess = s
    end
  end

  def http_get(url)
    p "wanna get #{url}"
    rest  unless @@rested
    @@rested = false
    @@sess.get url
  end

  def rest
    duration = 3+rand(6)
    p "tired. resting #{duration} seconds..."
    sleep duration
    @@rested = true
  end

  def get_url(serie)
    subtitles = {}
    subtitles[:page_url] = '/serie/%s/%s/%s/%s' % [serie[:name], serie[:season], serie[:episode], serie[:title]||'0']
    resp = http_get subtitles[:page_url]
    if resp.status < 400
      doc = Nokogiri::HTML resp.body
      subs = []
      doc.css('td.NewsTitle').each do |node|
        next  unless node.content.match /version/i
        sub = {}
        sub[:version] = node.content.gsub(/version/i, '').strip
        table = node.ancestors('table').first
        table.css('td.language').each do |lang|
          sub[:lang] = lang.content.strip
          sub[:status] = lang.next_element.content.strip
          links = lang.parent.css('td a').select{ |l| l[:href].match /original|updated/ }.sort
          sub[:links] = links.map{ |l| l[:href] }
          flags = lang.parent.next_element.css('img[title="Hearing Impaired"], img[title="Corrected"]')
          stats = lang.parent.next_element.children.first.content.strip.match /.*?(\d+) downloads.*?(\d+) sequences.*/i
          sub[:downloads] = stats[1].to_i
          sub[:sequences] = stats[2].to_i
          flags = sub[:version].split(/,[\s ]*/) + flags.map{|n| n[:title]}
          sub[:flags] = flags
          sub[:page] = subtitles[:page_url]
        end
        subs << sub
      end
      subtitles[:subs] = subs
    end

    #filter languages
    selected = subtitles[:subs].select do |sub|
      LANGS.include? sub[:lang].downcase
    end

    #drop incomplete
    selected.select! do |sub|
      sub.delete(:status).match /complete/i
    end

    #drop flags
    selected.select! do |sub|
      !sub[:flags].find{ |s| s.match_any DROP_FLAGS } && sub[:flags].find{ |s| s.match_any NEED_FLAGS }
    end

    #join versions
    versions = {}
    selected.each do |sub|
      ver = sub[:version]
      versions[ver] ||= []
      versions[ver] += sub[:flags]
      versions[ver].uniq!
    end
    selected.select! do |sub|
      sub[:flags] == versions[sub[:version]]
    end

    #sort
    selected.sort_by!{ |s| -(s[:sequences] + s[:downloads].to_f/1000) }

    #select link
    selected.each do |sub|
      sub[:link] = sub[:links].last
    end

    selected.first
  end

  def get_sub( sub )
    http_get sub[:link]
  end

end

craw = Craw.new

Dir.glob('*.mkv').each do |name|
  srt = name.gsub /\.mkv$/, '.srt'
  next  if File.exists? srt
  tags = name.match /^(.*)\.s(\d+)e(\d+)\.(.*)$/i
  next  unless tags
  serie = { name: tags[1].gsub('.','_').gsub(/_\d\d\d\d/, ''),
            season: tags[2],
            episode: tags[3],
            flags: tags[4].split('.') }
  ap "Searching sub for #{name}"
  meta = craw.get_url(serie)
  ap meta
  sub = craw.get_sub(meta)
  File.open(srt, 'wb') { |f| f << sub.body }
  ap "Writing sub #{srt}"
end
