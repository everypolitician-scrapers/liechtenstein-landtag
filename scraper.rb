#!/bin/env ruby
# encoding: utf-8
# frozen_string_literal: true

require 'pry'
require 'scraped'
require 'scraperwiki'

require 'open-uri/cached'
OpenURI::Cache.cache_path = '.cache'

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
    noko.css('.pic @style').text[/(http:.*?.(jpg|png))/, 1]
  end

  field :email do
    EMAIL_EXTRAS.reduce(raw_email) { |email, str| email.sub(str, '') }
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

  field :identifier__landtag do
    id
  end

  private

  # http://www.landtag.li/scripts/landtag-master.js?t=3 contains the
  # replacement codes. Assume for now that these are static. If they're
  # not, we'll need to fetch this and replace them dynamically.
  EMAIL_EXTRAS = %w[
    fss32ixh kvx7n3i7 p6gktryw kvx7n3i7 93Fu2 fss32ixh kvx7n3i7 p6gktryw kvx7n3i7 93Fu2
  ]

  def raw_email
    noko.css('.email a/@href').text.sub('mailto:', '')
  end

  def popup
    noko.at_css('.pic div p').children.map(&:text).reject(&:empty?)
  end
end

def scrape_list(termid, url)
  page = MembersPage.new(response: Scraped::Request.new(url: url).response)
  data = page.members.map do |mem|
    mem.to_h.merge(term: termid)
  end

  data.each { |mem| puts mem.reject { |_, v| v.to_s.empty? }.sort_by { |k, _| k }.to_h } if ENV['MORPH_DEBUG']
  ScraperWiki.save_sqlite(%i(name term), data)
end

terms = {
  2017 => 'https://www.landtag.li/abgeordnete/?jahr=2017',
  2013 => 'https://www.landtag.li/abgeordnete/?jahr=2013',
  2009 => 'https://www.landtag.li/abgeordnete/?jahr=2009',
  2005 => 'https://www.landtag.li/abgeordnete/?jahr=2005',
}

ScraperWiki.sqliteexecute('DROP TABLE data') rescue nil
terms.each { |id, url| scrape_list(id, url) }
