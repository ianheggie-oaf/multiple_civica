# frozen_string_literal: true

require "morph_status/morph_scraper"
require "morph_status/morph_api"
require "morph_status/authority_url_resolver"
require "civica_scraper"
require "yaml"

namespace :morph_status do
  desc "Generate a report of Planning Alerts authority statuses"
  task :report do
    authorities = CivicaScraper.selected_authorities
    morph_scanner = MorphStatus::MorphScraper.new

    # Calculate column widths dynamically
    column_widths = calculate_max_column_widths(authorities, morph_scanner)

    # Prepare header with dynamic widths
    header_format = "%-#{column_widths[:authority]}s %#{column_widths[:week]}s " \
      "%#{column_widths[:month]}s %#{column_widths[:population]}s %#{column_widths[:test]}s " \
      "%#{column_widths[:morph]}s %s\n"

    printf header_format,
           "Authority", "Week", "Month", "Population", "Test", "Morph", "Warning"
    printf header_format,
           "-" * column_widths[:authority], "-" * column_widths[:week],
           "-" * column_widths[:month], "-" * column_widths[:population],
           "-" * column_widths[:test], "-" * column_widths[:morph],
           "-" * 40

    api_data = MorphStatus::MorphApi.fetch_morph_data
    authorities_data = {}
    authorities.each do |authority|
      data = morph_scanner.fetch_authority_data(authority)

      data[:test_count] = load_test_count(authority)

      data.merge! api_data[authority] if api_data.key? authority

      authorities_data[authority] = data

      # Format and print the output row
      printf header_format,
             authority.to_s,
             data[:week] || "-",
             data[:month] || "-",
             data[:population] || "-",
             data[:test_count] || "-",
             data[:morph_count] || "-",
             data[:warning] || "-"

    rescue StandardError => e
      puts "Error processing #{authority}: #{e.message}"
    end

    puts "",
         "KEY:",
         "Week, Month, Population, Warning - from Morph.io Live Status Page",
         "Test - local spec/expected/AUTHORITY.yml record count",
         "Morph - records collected by test of this repo on Morph.io",
         ""

    # Generate summary
    generate_summary(authorities_data)
  end

  def load_test_count(authority)
    expected_file = File.join("spec", "expected", "#{authority}.yml")
    return 0 unless File.exist?(expected_file)

    YAML.load_file(expected_file).count
  rescue StandardError
    0
  end

  def calculate_max_column_widths(authorities, morph_scanner)
    {
      authority: [
        "Authority".length,
        authorities.map { |a| a.to_s.length }.max
      ].max,
      week: [
        "Week".length,
        authorities.map { |a| morph_scanner.fetch_authority_data(a)[:week].to_s.length }.max
      ].max,
      month: [
        "Month".length,
        authorities.map { |a| morph_scanner.fetch_authority_data(a)[:month].to_s.length }.max
      ].max,
      test: [
        "Test".length,
        authorities.map do |a|
          test_file = "spec/expected/#{a}.yml"
          File.exist?(test_file) ? YAML.load_file(test_file).count.to_s.length : 0
        end.max
      ].max,
      population: [
        "Population".length,
        authorities.map { |a| morph_scanner.fetch_authority_data(a)[:population].to_s.length }.max
      ].max,
      morph: [
        "Morph".length,
        authorities.map { |a| morph_scanner.fetch_authority_data(a)[:morph_count].to_s.length }.max
      ].max
    }
  end

  def wrap_list(items, indent, width = 80)
    return "" if items.empty?

    lines = ["#{indent}#{items.first}"]
    items.drop(1).each do |item|
      if lines.last.length + 2 + item.length > width
        lines << "#{indent}#{item}"
      else
        lines[-1] = "#{lines.last}, #{item}"
      end
    end
    lines.join("\n")
  end

  def generate_summary(authorities_data)
    puts "\nSummary:"

    # Categorize authorities
    fixed = []
    works_locally = []
    newly_broken = []
    missing_status = []
    still_broken = []
    changed_scraper = []
    working = []
    needs_morph_run = []

    authorities_data.each do |authority, data|
      # Check for missing status page first
      unless data[:week] && data[:month] && data[:scraper]
        puts "Authority #{authority} missing status in #{data.inspect}" if ENV["DEBUG"]
        missing_status << authority
        next
      end

      broken_here = !data[:test_count]&.positive?
      broken_prod = !data[:month]&.positive?
      if data[:last_scraped]
        # Check if Morph data is stale
        needs_morph_run << authority if data[:last_scraped] < Date.today - 1
      end

      if data[:scraper] != CivicaScraper::MORPH_SCRAPER
        changed_scraper << authority
        next
      end

      if broken_prod
        if broken_here
          still_broken << authority
        elsif data[:morph_count]&.positive?
          fixed << authority
        else
          works_locally << authority
        end
      else
        # working in production
        if broken_here
          newly_broken << authority
        else
          working << authority
        end
      end
    end

    puts "\nActions to Take:"
    indent = "   "

    if missing_status.any?
      puts "🔍 #{missing_status.count} Missing Status Page (Action: Investigate scraper configuration)"
      puts wrap_list(missing_status, indent)
    end

    if newly_broken.any?
      puts "🔴 #{newly_broken.count} Newly Broken (Action: Debug and fix)"
      puts wrap_list(newly_broken, indent)
    end

    if needs_morph_run.any?
      puts "🕰️ #{needs_morph_run.count} Stale Morph Data (Action: Trigger Morph.io run)"
      if ENV["MORPH_API_KEY"]
        puts wrap_list(needs_morph_run, indent)
      else
        puts "#{indent}Set MORPH_API_KEY environment variable before running"
      end
    end

    if works_locally.any?
      puts "🟡 #{works_locally.count} Works Locally (Action: Run on Morph.io for final check)"
      puts wrap_list(works_locally, indent)
      unless ENV["MORPH_API_KEY"]
        puts "#{indent}Tip: Set MORPH_API_KEY environment variable before running"
      end
    end

    if fixed.any?
      puts "🟢 #{fixed.count} Fixed (Tag release and request release to production via associated issue)"
      puts wrap_list(fixed, indent)
    end

    if still_broken.any?
      puts "🟡 #{still_broken.count} Still Broken (Action: Debug and fix)"
      puts wrap_list(still_broken, indent)
    end

    if changed_scraper.any?
      puts "🟠 #{changed_scraper.count} Changed Scraper (remove from this scrapper if working):"
      changed_scraper.each do |authority|
        puts "#{indent}- #{authority} - now uses #{authorities_data[authority][:scraper]}"
      end
    end

    if working.any?
      puts "🟢 #{working.count} Working locally and on Morph.io"
      puts wrap_list(working, indent)
    end

    puts "",
         "Development repo: #{MorphStatus::MorphApi.github_repo_name}",
         "         Version: #{CivicaScraper::VERSION}",
         "Live scraper:     #{CivicaScraper::MORPH_SCRAPER}"
  end
end
