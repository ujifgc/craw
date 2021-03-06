#!/usr/bin/env ruby
#coding:utf-8

require 'awesome_print'
require 'nokogiri'
require 'patron'

LANGS = %w(english)

RELEASE_GROUPS = %W(lol dimension asap immerse 2hd bia tla orenji ctu fqm avs p0w4 fov)
WORK_GROUPS = [
  [/dimension/i, /lol/i],
  [/immerse/i, /asap/i],
  [/fqm/i, /orenji/i],
]
SERIES_MAP = {
  /the_office_us/i => 'The_Office_(US)',
  /Charlie.?s_Angels/i => "Charlie's_Angels",
  /the_la_complex/i => 'The_L.A._Complex',
  /the_l_a_complex/i => 'The_L.A._Complex',
  /shameless.*u.*s/i => 'Shameless_(US)',
  /terminator.the.sarah.connor.chronicles/i => 'Terminator%3A_The_Sarah_Connor_Chronicles',
  /Marvels.Agents.of.S.H.I.E.L.D/i => "Marvel's_Agents_of_S.H.I.E.L.D.",
  /Scandal.US/i => 'Scandal',
}

class String
  def squeeze
    self.gsub(/ +/, ' ').strip
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
  @@fresh = true

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
    print ".. wanna get #{url}, "
    loop do
      begin
        rest
        return @@sess.get(url)
      rescue Exception => e
        ap "! exception #{e}"
      end
    end
  end

  def rest
    if @@fresh
      @@fresh = false
      return
    end
    duration = 1+rand(2)
    print "waiting #{duration} seconds...\n"
    sleep duration
  end

  def get_url(serie)
    subtitles = {}
    subtitles[:page_url] = '/serie/%s/%s/%s/%s' % [serie[:name], serie[:season], serie[:episode], serie[:title]||'0']
    resp = http_get subtitles[:page_url]
    ap status: resp.status, size: resp.body.length

    if resp.body.length < 30
      ap "! page seems to be empty"
      return nil
    end
    if resp.status >= 400
      ap "! page does not exist"
      return nil
    end

    #extract subtitle versions
    doc = Nokogiri::HTML resp.body
    subs = []
    titles = doc.css('td.NewsTitle')
    titles.each do |node|
      next  unless node.content.match /version/i
      table = node.ancestors('table').first
      legend = table.css('td.newsDate').first
      legend = legend.content.squeeze  if legend
      table.css('td.language').each do |lang|
        sub = {}
        sub[:version] = node.content.gsub(/version/i, '').squeeze
        sub[:lang] = lang.content.squeeze
        sub[:status] = lang.next_element.content.squeeze
        links = lang.parent.css('td a').select{ |l| l[:href].match /original|updated/ }.sort
        sub[:links] = links.map{ |l| l[:href] }
        flags = lang.parent.next_element.css('img[title="Hearing Impaired"], img[title="Corrected"]')
        stats = lang.parent.next_element.children.first.content.squeeze.match /.*?(\d+) downloads.*?(\d+) sequences.*/i
        if stats
          sub[:downloads] = stats[1].to_i
          sub[:sequences] = stats[2].to_i
        end
        flags = sub[:version].split(/,[\s ]*/) + flags.map{|n| n[:title]}
        sub[:flags] = flags
        sub[:page] = subtitles[:page_url]
        sub[:flags] << 'web-dl'  if table.content.match /web.?dl/i
        sub[:legend] = legend || ''
        subs << sub
      end
    end
    subtitles[:subs] = subs

    #filter languages
    selected = subtitles[:subs].select do |sub|
      LANGS.include? sub[:lang].downcase
    end

    #drop incomplete
    selected.select! do |sub|
      sub.delete(:status).match /complete/i
    end

    #drop sequenceless
    selected.select! do |sub|
      sub[:sequences] > 10
    end

    #investigate version tags
    versions = {}
    selected.each do |sub|
      ver = sub[:version]
      versions[ver] ||= []
      versions[ver] += sub[:flags]
      versions[ver].uniq!
    end

    #try to select the richest version
    selected.select! do |sub|
      sub[:flags].sort == versions[sub[:version]].sort
    end

    #select the last link and drop the rest
    selected.each do |sub|
      sub[:link] = sub.delete(:links).last
    end

    #try to find exact match
    fidx = nil
    idx = selected.index do |s|
      fidx = s[:flags].index do |f|
        f.match /#{serie[:rg]}/i
      end
    end
    if idx
      ap "! found exact match: '#{selected[idx][:flags][fidx]}' == '#{serie[:rg]}'"
      return selected[idx]  
    end

    #try to find the match likely to work
    WORK_GROUPS.each do |rgs|
      ok_flags = rgs  if serie[:rg].match_any rgs
      next  unless ok_flags
      fidx = nil
      idx = selected.index do |s|
        fidx = s[:flags].index do |f|
          f.match_any ok_flags
        end
      end
      if idx
        ap "! found group match: '#{selected[idx][:flags][fidx]}' should work with '#{serie[:rg]}'"
        return selected[idx]  
      end
    end

    #try to find the match mentioned in the legend
    lidx = selected.index do |s|
      s[:legend].match /#{serie[:rg]}/i
    end
    if lidx
      ap "! found mentioned match: '#{selected[lidx][:legend]}' contains '#{serie[:rg]}'"
      return selected[lidx]  
    end

    #fail it
    ap "! exact match not found, selecting first subtitle"
    selected.first
  end

  def get_sub( sub )
    http_get sub[:link]
  end

end

def prepare_name(s)
  s = s.gsub('.','_').gsub(/_\d\d\d\d/, '')
  SERIES_MAP.to_a.each do |a|
    s = s.gsub a[0], a[1]
  end
  s
end

def extract_rg(s)
  s = s.join('.')  if s.kind_of? Array
  RELEASE_GROUPS.each do |rg|
    return rg  if s.match /#{rg}/i
  end
  s.split(/\-|\./).last
end

craw = Craw.new

Dir.chdir ARGV[0] || '.'
Dir.glob('*.{mkv,avi}').sort.each do |name|
  name = File.basename name, File.extname(name)
  srt = name + '.srt'
  next  if File.exists? srt
  tags = name.match( /^(.*)\.s(\d+)e(\d+)\.(.*)$/i ) || name.match( /^(.*)\.(\d+)x(\d+)\.(.*)$/i ) || name.match( /^(.*)\.(\d)(\d\d)\.(.*)$/i )
  unless tags
    tags = name.match( /^(.*)\.s(\d+)e(\d+)\-?e\d+\.(.*)$/i ) || name.match( /^(.*)\.(\d)(\d\d)\d\d\.(.*)$/i )
    @double = name.match( /^(.*)\.s(\d+)e\d+\-?e(\d+)\.(.*)$/i ) || name.match( /^(.*)\.(\d)\d\d(\d\d)\.(.*)$/i )
  end
  next  unless tags
  serie = { name: prepare_name(tags[1]),
            season: tags[2],
            episode: tags[3],
            flags: tags[4].split('.'),
            rg: extract_rg(tags[4]) }
  while true
    ap "? searching sub for #{name} s.#{serie[:season]} e.#{serie[:episode]} (tags: #{serie[:flags].join(', ')}, rg: #{serie[:rg]})"
    meta = craw.get_url(serie)
    if meta
      ap meta
      sub = craw.get_sub(meta)
      if sub.body[0] == "<"
        ap "! looks like we are banned for the day"
        raise Exception, "got a subtitle with '<' as first byte"
      else
        File.open(srt, 'wb') { |f| f << sub.body }
        ap "= writing sub #{srt}"
      end
      break
    else
      ap "- failed to extract meta"
      if @double
        ap "? trying to get meta from double serie"
        serie[:episode] = @double[3]
        @double = nil
      else
        break
      end
    end
  end
end
