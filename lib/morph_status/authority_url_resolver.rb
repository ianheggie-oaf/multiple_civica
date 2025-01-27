# frozen_string_literal: true

require "mechanize"

module MorphStatus
  class AuthorityUrlResolver
    def self.authority_hrefs
      @authority_hrefs ||=
        begin
          agent = Mechanize.new
          page = agent.get("https://www.planningalerts.org.au/authorities")

          # Store all links directly
          result = page.links
                       .map(&:href)
                       .map(&:to_s)
                       .map { |href| href.sub("https://www.planningalerts.org.au", "") }
                       .select { |href| href.start_with?("/authorities/") }
                       .sort
          puts "AUTHORITY HREFS: #{result.to_yaml}" if ENV["DEBUG"]
          result
        end
    end

    def self.get_href_for(authority)
      multiple_matches = nil
      [
        "/authorities/#{authority}",
        "/authorities/#{authority.to_s.gsub('_', '')}",
        "/authorities/#{authority.to_s.sub(/_[^_]*$/, '')}",
        "/authorities/#{authority.to_s.sub(/_[^_]*_[^_]*$/, '')}"
      ].uniq.each do |href|
        return href if authority_hrefs.include?(href)

        matches = authority_hrefs.select { |a_href| a_href.start_with?(href) }
        return matches.first if matches.size == 1

        multiple_matches = matches if matches.any?
      end
      warn "No unique URL found for authority: #{authority}, found: #{multiple_matches&.join(', ')}"
      nil
    end
  end
end
