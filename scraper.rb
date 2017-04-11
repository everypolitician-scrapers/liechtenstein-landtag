#!/bin/env ruby
# encoding: utf-8
# frozen_string_literal: true

require 'pry'
require 'scraped'
require 'scraperwiki'

# require 'open-uri/cached'
# OpenURI::Cache.cache_path = '.cache'
require 'scraped_page_archive/open-uri'

class MembersPage < Scraped::HTML
  field :members do
    noko.css('div#personen .member').reject do |mp|
      mp.xpath('preceding::h2').map(&:text).last == 'Stellvertreter der Abgeordneten'
    end.map do |mp|
      fragment mp => MemberDiv
    end
  end
end

class MemberDiv < Scraped::HTML
  field :id do
    noko.at_css('@data-id').text
  end

  field :name do
    noko.css('.name a').text.tidy
  end

  field :image do
    noko.css('.pic @style').text[/(http:.*?.jpg)/, 1]
  end

  field :email do
    noko.css('.email a/@href').text.sub('mailto:', '')
  end

  field :party do
    popup[1]
  end

  field :party_id do
    popup[1]
  end

  field :birth_date do
    popup[2].to_s.split('.').reverse.join('-')
  end

  field :region do
    noko.xpath('preceding::h3').map(&:text).last
  end

  field :end_date do
    noko.css('.name').text[/Zurückgetreten am (\d{2}.\d{2}.\d{4})/, 1].to_s.split('.').reverse.join('-')
  end

  field :source do
    url
  end

  private

  def popup
    noko.at_css('.pic div p').children.map(&:text).reject(&:empty?)
  end
end

def scrape_list(termid, url)
  page = MembersPage.new(response: Scraped::Request.new(url: url).response)
  data = page.members.map do |mem|
    mem.to_h.merge(term: termid)
  end

  # puts data.map { |mem| mem.reject { |k, v| v.to_s.empty? }.sort_by { |k, v| k }.to_h }
  ScraperWiki.save_sqlite(%i(name term), data)
end

terms = {
  2013 => 'http://www.landtag.li/abgeordnete/?jahr=2013',
  2009 => 'http://www.landtag.li/abgeordnete/?jahr=2009',
  2005 => 'http://www.landtag.li/abgeordnete/?jahr=2005',
}

ScraperWiki.sqliteexecute('DELETE FROM data') rescue nil
terms.each { |id, url| scrape_list(id, url) }
