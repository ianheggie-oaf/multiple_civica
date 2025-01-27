# frozen_string_literal: true

require "net/http"
require "uri"
require "json"

module MorphStatus
  class MorphApi
    def self.api_key
      ENV["MORPH_API_KEY"]
    end

    def self.github_repo_name
      return ENV["MORPH_REPO"] if ENV["MORPH_REPO"]

      remotes = `git remote -v 2> /dev/null`.split("\n")

      remotes.each do |remote|
        # Match SSH format: git@github.com:owner/repo.git
        ssh_match = remote.match(%r{github\.com[:|/]([^/]+/[^/]+)\.git})
        return ssh_match[1] if ssh_match

        # Match HTTPS format: https://github.com/owner/repo.git
        https_match = remote.match(%r{https://github\.com/([^/]+/[^/]+)\.git})
        return https_match[1] if https_match
      end

      nil
    rescue StandardError
      nil
    end

    def self.fetch_morph_data
      repo = github_repo_name
      unless api_key
        warn "WARNING: MORPH_API_KEY is not set! Final checks cannot be performed"
        return {}
      end
      unless repo
        warn "WARNING: Unable to determine github repo and MORPH_REPO is not set!" \
               "Final checks cannot be performed"
        return {}
      end

      name_column = "authority_label"
      count_column = "count(*)"
      date_column = "max(date_scraped)"
      url = [
        "https://api.morph.io/",
        repo,
        "/data.json?",
        "key=#{api_key}&",
        "query=select #{name_column}%2C#{count_column}%2C#{date_column} ",
        "from %22data%22 group by 1"
      ].join("").gsub(" ", "%20")
      uri = URI(url)
      puts "MORPH API CALL: #{url}" if ENV["DEBUG"]
      response = Net::HTTP.get(uri)
      result = {}
      JSON.parse(response).each do |data|
        last_scraped = Date.parse(data[date_column])
        result[data[name_column].to_sym] = {
          morph_count: data[count_column],
          last_scraped: last_scraped
        }
      end
      puts "Result: #{result.to_yaml}" if ENV["DEBUG"]
      result
    rescue StandardError => e
      puts "Error fetching Morph data: #{e.message}"
      {}
    end
  end
end
