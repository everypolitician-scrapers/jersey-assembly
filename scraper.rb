#!/bin/env ruby
# encoding: utf-8

require 'scraperwiki'
require 'nokogiri'
require 'open-uri'
require 'pry'

require 'open-uri/cached'
OpenURI::Cache.cache_path = '.cache'

class String
  def tidy
    self.gsub(/[[:space:]]+/, ' ').strip
  end
end

def noko_for(url)
  Nokogiri::HTML(open(url).read) 
end

def scrape_list(url)
  noko = noko_for(url)
  noko.css('#members a[href*="?MemberId"]').each do |member|
    link = URI.join url, member.attr('href')
    scrape_mp(link, member.text.strip.split(' - ').first)
  end
end

def scrape_mp(url, name)
  noko = noko_for(url)
  position, fullname = noko.css('#ctl00_PlaceHolderMain_EditModePanelintroview_Members_lblTitle').text.strip.split(' - ').map(&:tidy)

  data = { 
    id: url.to_s[/MemberId=(\d+)/, 1],
    name: fullname,
    position: position,
    family_name: name.split(', ').first.strip,
    given_name: name.split(', ').last.strip,
    sort_name: name,
    parish: noko.xpath('.//div[contains(text(), "Parish")]/following::p[1]').text.strip,
    email: noko.css('a[href*="mailto"]/@href').map(&:text).find { |e| e.include? 'gov.je' }.to_s.sub('mailto:',''),
    party: 'Independent',
    photo: noko.css('img#ctl00_PlaceHolderMain_EditModePanelintroview_Members_imgMember/@src').text,
    term: 2011,
    source: url.to_s,
  }
  data[:photo] = URI.join(url, data[:photo]).to_s unless data[:photo].empty?
  puts data.reject { |_, v| v.to_s.empty? }.sort_by { |k, _| k }.to_h if ENV['MORPH_DEBUG']
  ScraperWiki.save_sqlite([:id, :term], data)
end

scrape_list('http://www.statesassembly.gov.je/Pages/Members.aspx?FilterBy=name')
