# frozen_string_literal: true

require "timecop"

def vcr_recording_date
  date_file = "spec/vcr_date.txt"
  if File.exist?(date_file)
    Date.parse(File.read(date_file))
  else
    today = Date.today
    File.write(date_file, today.to_s)
    today
  end
end

RSpec.describe CivicaScraper do
  it "has a version number" do
    expect(CivicaScraper::VERSION).not_to be nil
  end

  describe ".scrape_and_save" do
    def test_scrape_and_save(authority)
      File.delete("./data.sqlite") if File.exist?("./data.sqlite")

      limit = ENV["LIMIT"]
      vcr_key = if limit
                  "limited_to_#{limit}_#{authority}"
                else
                  authority
                end

      VCR.use_cassette(vcr_key) do
        Timecop.freeze(vcr_recording_date) do
          CivicaScraper.scrape_and_save(authority)
        end
      end

      expected_path = "spec/expected/#{vcr_key}.yml"
      expected = if File.exist?(expected_path)
                   YAML.safe_load(File.read(expected_path))
                 else
                   []
                 end
      results = ScraperWiki.select("* from data order by council_reference")

      ScraperWiki.close_sqlite

      if results != expected
        unless results.empty?
          timing = "next " unless expected.empty?
          puts "NOTE: Overwrote #{timing}expected so that we can compare with version control"
          puts "      (and maybe commit if it is correct)"
          File.open(expected_path, "w") do |f|
            f.write(results.to_yaml)
          end
          expected = results if expected.empty?
        end
      end

      expect(results).to eq expected
    end

    CivicaScraper.selected_authorities.each do |authority|
      it authority do
        test_scrape_and_save(authority)
      end
    end
  end
end
