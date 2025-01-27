# frozen_string_literal: true

$LOAD_PATH << "./lib"

require "rspec/core/rake_task"
require "watir"
require "civica_scraper"
require "mini_magick"
require "fileutils"

Dir.glob('lib/tasks/*.rake').each { |r| load r }

RSpec::Core::RakeTask.new(:spec)

task default: :spec

desc "Take a screenshots of all the council sites to embed in the documentation"
task :screenshots do
  browser = Watir::Browser.new
  CivicaScraper::AUTHORITIES.each do |k, v|
    browser.goto v[:url]
    browser.screenshot.save "screenshots/#{k}.png"
  end
  # Now combine the screenshots into one
  MiniMagick::Tool::Montage.new do |montage|
    montage.mode "unframe"
    montage.background "#000000"
    montage.geometry "600x355+20+20"
    CivicaScraper::AUTHORITIES.each do |k, _v|
      montage << "screenshots/#{k}.png"
    end
    montage << "screenshots/all.jpg"
  end
  # Clean up
  CivicaScraper::AUTHORITIES.each do |k, _v|
    File.delete("screenshots/#{k}.png")
  end
end

desc "Clobber cache of external site responses"
task :clobber_cache do
  puts "Clobbering cache of external site responses ..."
  FileUtils.rm_f(Dir.glob("spec/cassettes/*"))
  puts "Clobbering expected records from external sites ..."
  FileUtils.rm_f(Dir.glob("spec/expected/*"))
  puts "Clobbering vcr recording date so it will be recreated next time specs are run"
  FileUtils.rm_f("spec/vcr_date.txt")
end
