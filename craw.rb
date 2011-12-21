#!/usr/bin/ruby1.9.1
#coding:utf-8

require 'awesome_print'
require 'nokogiri'
require 'patron'

LANGS = %w(english russian)

LIKE_FLAGS = [ /720p?/i, /LOL/i, /ASAP/i, /bia/i ]
NEED_FLAGS = [ /.*/i ]
DROP_FLAGS = [ /web.?dl/i, /dvd.?rip/i ]
WORK_PAIRS = {
  'immerse' => /asap/i,
  'dimension' => /lol/i }
RELEASE_GROUPS = %W(lol dimension asap immerse 2hd bia tla orenji)

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
      s.headers['User-Agent'] = 'Mozilla/4.0 (X11; U; Linux x86_64; en-US; rv:1.9.1.3)'
      s.headers['Referer'] = s.base_url
      s.timeout = 15000
      @@sess = s
    end
  end

  def http_get(url)
    p "wanna get #{url}"
    rest  unless @@rested
    @@rested = false
    begin
      @@sess.get url
    rescue # Patron::HostResolutionError
      p 'oops... unresolved hostname. it happens, retrying'
      rest
      @@sess.get url
    end
  end

  def rest
    duration = 2+rand(4)
    p "waiting #{duration} seconds..."
    sleep duration
    @@rested = true
  end

  def get_url(serie)
    subtitles = {}
    subtitles[:page_url] = '/serie/%s/%s/%s/%s' % [serie[:name], serie[:season], serie[:episode], serie[:title]||'0']
    resp = http_get subtitles[:page_url]
    ap status: resp.status, size: resp.body.length
    if resp.status < 400
      doc = Nokogiri::HTML resp.body
      subs = []
      titles = doc.css('td.NewsTitle')
      titles.each do |node|
        next  unless node.content.match /version/i
        table = node.ancestors('table').first
        table.css('td.language').each do |lang|
          sub = {}
          sub[:version] = node.content.gsub(/version/i, '').strip
          sub[:lang] = lang.content.strip
          sub[:status] = lang.next_element.content.strip
          links = lang.parent.css('td a').select{ |l| l[:href].match /original|updated/ }.sort
          sub[:links] = links.map{ |l| l[:href] }
          flags = lang.parent.next_element.css('img[title="Hearing Impaired"], img[title="Corrected"]')
          stats = lang.parent.next_element.children.first.content.strip.match /.*?(\d+) downloads.*?(\d+) sequences.*/i
          if stats
            sub[:downloads] = stats[1].to_i
            sub[:sequences] = stats[2].to_i
          end
          flags = sub[:version].split(/,[\s ]*/) + flags.map{|n| n[:title]}
          sub[:flags] = flags
          sub[:page] = subtitles[:page_url]
          sub[:flags] << 'web-dl'  if table.content.match /web.?dl/i
          subs << sub
        end
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
      sub[:flags].sort == versions[sub[:version]].sort
    end

    #sort
    selected.sort_by!{ |s| -(s[:sequences] + s[:downloads].to_f/1000) }

    #select link
    selected.each do |sub|
      sub[:link] = sub[:links].last
    end

    LIKE_FLAGS.reverse.each do |lf|
      idx = selected.index{ |s| s[:flags].index{ |f| f.match(lf) } }
      return selected[idx]  if idx
    end
    selected.first
  end

  def get_sub( sub )
    http_get sub[:link]
  end

end

def prepare_name(s)
  s = s.gsub('.','_').gsub(/_\d\d\d\d/, '')
  h = {
    /the_office_us/i => 'The_Office_(US)',
    /Charlie.?s_Angels/i => "Charlie's_Angels"
  }
  h.to_a.each do |a|
    s = s.gsub a[0], a[1]
  end
  s
end

def extract_rg(s)
  s = s.join('.')  if s.kind_of? Array
  RELEASE_GROUPS.each do |rg|
    return rg  if s.match /#{rg}/i
  end
end

craw = Craw.new

Dir.glob('*.mkv').each do |name|
  srt = name.gsub /\.mkv$/, '.srt'
  next  if File.exists? srt
  tags = name.match( /^(.*)\.s(\d+)e(\d+)\.(.*)$/i )
  unless tags
    tags = name.match( /^(.*)\.s(\d+)e(\d+)e\d+\.(.*)$/i )
    @double = name.match( /^(.*)\.s(\d+)e\d+e(\d+)\.(.*)$/i )
  end
  next  unless tags
  name = prepare_name(tags[1])
  serie = { name: name,
            season: tags[2],
            episode: tags[3],
            flags: tags[4].split('.'),
            rg: extract_rg(tags[4]) }
  while true
    ap "Searching sub for #{name} ep.#{serie[:episode]} (tags: #{serie[:flags].join(', ')}, rg: #{serie[:rg]})"
    meta = craw.get_url(serie)
    if meta
      ap meta
      sub = craw.get_sub(meta)
      File.open(srt, 'wb') { |f| f << sub.body }
      ap "Writing sub #{srt}"
      break
    else
      ap "Failed to extract meta"
      if @double
        ap "Trying to get meta from double serie"
        serie[:episode] = @double[3]
      else
        break
      end
    end
  end
end
