#!/usr/bin/env ruby
# frozen_string_literal: true

Bundler.require

$LOAD_PATH << "./lib"

require "civica_scraper"

# fix errors reporting after next stdout message in morph.io
STDOUT.sync = true
STDERR.sync = true

def scrape(authorities)
  exceptions = {}
  authorities.each do |authority_label|
    last_time = Time.now
    puts "\nCollecting feed data for #{authority_label} at #{last_time} ..."
    begin
      CivicaScraper.scrape(authority_label) do |record|
        record["authority_label"] = authority_label.to_s
        CivicaScraper.log(record)
        ScraperWiki.save_sqlite(%w[authority_label council_reference], record)
      end
    rescue StandardError => e
      seconds = (Time.now - last_time).round(1)
      warn "#{authority_label}: ERROR: #{e} after #{seconds} seconds"
      warn e.backtrace
      exceptions[authority_label] = e
    end
  end
  exceptions
end

authorities = CivicaScraper.selected_authorities

puts "Scraping authorities: #{authorities.join(', ')} at #{Time.now}"
exceptions = scrape(authorities)

unless exceptions.empty?
  retrying = exceptions.keys
  puts "\n***************************************************"
  puts "Now retrying authorities which earlier had failures at #{Time.now}:"
  puts retrying.join(", ")
  puts "***************************************************"

  exceptions = scrape(retrying)
  unless (retrying - exceptions.keys).empty?
    puts "Resolved when retried: #{(retrying - exceptions.keys).join(', ')}"
  end
end
if ENV["MORPH_AUSTRALIAN_PROXY"] && !exceptions.empty?
  retrying = exceptions.keys
  ENV["MORPH_AUSTRALIAN_PROXY"] = nil
  puts "\n***************************************************"
  puts "Now retrying authorities which earlier had failures without australian proxy at #{Time.now}:"
  puts retrying.join(", ")
  puts "***************************************************"

  exceptions = scrape(retrying)
  unless (retrying - exceptions.keys).empty?
    puts "Resolved when retried: #{(retrying - exceptions.keys).join(', ')}"
  end
end
puts "Finished at #{Time.now}"

unless exceptions.empty?
  raise "There were still errors with the following authorities when retried: #{exceptions.keys}. "\
        "See earlier output for details"
end
