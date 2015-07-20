#!/bin/env ruby
# encoding: utf-8

require 'scraperwiki'
require 'nokogiri'
require 'open-uri'
require 'colorize'

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

def party_info(text)
  if text =~ /Fiji First/i
    return [ "Fiji First", "FF" ]
  elsif text =~ /SODELPA/
    return [ "Social Democratic Liberal Party" , "SODELPA" ]
  elsif text =~ /NATIONAL FEDERATION PARTY/
    return [ "National Federation Party" , "NFP" ]
  else
    warn "Unknown party: #{text}"
  end
end

def scrape_list(termid, url)
  noko = noko_for(url)

  noko.css('div#personlist .regionheader').each do |region|
    region.xpath('.//following-sibling::table[1]//td').each do |mp|
      info = mp.css('div.personinfo')
      next if mp.css('h3').text.empty?
       # binding.pry
      data = { 
        id: mp.css('div.overlaybox/@data-item').text,
        name: mp.css('h3').text.tidy,
        image: mp.css('.imagebox img/@src').text,
        email: info.css('.iemail/@dataitem').text,
        party: info.css('p')[1].text,
        party_id: info.css('p')[1].text,
        region: region.text,
        term: termid,
        source: url,
      }
      ScraperWiki.save_sqlite([:name, :term], data)
    end
  end
end

terms = { 
  '2013-2017' => 'http://www.landtag.li/personen.aspx?nid=4158&auswahl=4158&lang=de',
  '2009-2013' => 'http://www.landtag.li/personen.aspx?nid=4158&auswahl=4158&lang=de&jahr=2009&sitzordnung=0',
  '2005-2009' => 'http://www.landtag.li/personen.aspx?nid=4158&auswahl=4158&lang=de&jahr=2005&sitzordnung=0',
}

terms.each do |id, url|
  start_date, end_date = id.split('-')
  term = { 
    id: start_date,
    name: id,
    start_date: start_date,
    end_date: end_date,
    source: url,
  }
  puts term
  ScraperWiki.save_sqlite([:id], term, 'terms')
  scrape_list(id, url)
end
