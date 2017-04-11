#!/bin/env ruby
# encoding: utf-8
# frozen_string_literal: true

require 'pry'
require 'scraped'
require 'scraperwiki'

# require 'open-uri/cached'
# OpenURI::Cache.cache_path = '.cache'
require 'scraped_page_archive/open-uri'

def noko_for(url)
  Nokogiri::HTML(open(url).read)
end

def scrape_list(termid, url)
  noko = noko_for(url)

  count = 0
  noko.css('div#personen .member').each do |mp|
    popup = mp.at_css('.pic div p').children.map(&:text).reject(&:empty?)

    data = {
      id:         mp.at_css('@data-id').text,
      name:       mp.css('.name a').text.tidy,
      image:      mp.css('.pic @style').text[/(http:.*?.jpg)/, 1],
      email:      mp.css('.email a/@href').text.sub('mailto:',''),
      party:      popup[1],
      party_id:   popup[1],
      birth_date: popup[2].to_s.split('.').reverse.join('-'),
      region:     mp.xpath('preceding::h3').text,
      term:       termid,
      source:     url,
    }
    count += 1
    # puts data
    ScraperWiki.save_sqlite(%i(name term), data)
  end
  puts "Added #{count}"
end

terms = {
  2013 => 'http://www.landtag.li/abgeordnete/?jahr=2013',
  2009 => 'http://www.landtag.li/abgeordnete/?jahr=2009',
  2005 => 'http://www.landtag.li/abgeordnete/?jahr=2005',
}

ScraperWiki.sqliteexecute('DELETE FROM data') rescue nil
terms.each { |id, url| scrape_list(id, url) }
