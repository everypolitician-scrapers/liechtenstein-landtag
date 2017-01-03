#!/bin/env ruby
# encoding: utf-8
# frozen_string_literal: true

require 'nokogiri'
require 'pry'
require 'scraperwiki'

require 'open-uri/cached'
OpenURI::Cache.cache_path = '.cache'

class String
  def tidy
    gsub(/[[:space:]]+/, ' ').strip
  end
end

def noko_for(url)
  Nokogiri::HTML(open(url).read)
end

def scrape_list(termid, url)
  noko = noko_for(url)

  count = 0
  noko.css('div#personlist .regionheader').each do |region|
    region.xpath('.//following-sibling::table[1]//td').each do |mp|
      info = mp.css('div.personinfo')
      next if mp.xpath('.//preceding::h2').count == 2
      next if mp.css('h3').text.empty?
      data = {
        id:       mp.css('div.overlaybox/@data-item').text,
        name:     mp.css('h3').text.tidy,
        image:    mp.css('.imagebox img/@src').text,
        email:    info.css('.iemail/@dataitem').text,
        party:    info.css('p')[1].text,
        party_id: info.css('p')[1].text,
        region:   region.text,
        term:     termid,
        source:   url,
      }
      count += 1
      # puts data
      ScraperWiki.save_sqlite(%i(name term), data)
    end
  end
  puts "Added #{count}"
end

terms = {
  '2013-2017' => 'http://www.landtag.li/personen.aspx?nid=4158&auswahl=4158&lang=de',
  '2009-2013' => 'http://www.landtag.li/personen.aspx?nid=4158&auswahl=4158&lang=de&jahr=2009&sitzordnung=0',
  '2005-2009' => 'http://www.landtag.li/personen.aspx?nid=4158&auswahl=4158&lang=de&jahr=2005&sitzordnung=0',
}

terms.each do |id, url|
  start_date, end_date = id.split('-')
  scrape_list(start_date, url)
end
