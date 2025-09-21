require "octokit"
require "time"
require_relative "app/models"

ORG = ENV.fetch("ORG", "vercel") # GitHub organization to fetch data from
ONLY_REPO = ENV["ONLY_REPO"]    # If set, only fetch data for this repository (e.g. "vercel/next.js")

def client
  @client ||= Octokit::Client.new(access_token: ENV.fetch("GITHUB_TOKEN"))
end

# Helpers

def with_retries(max_retries: 5)
  tries = 0
  begin
    return yield
  rescue Octokit::TooManyRequests, Octokit::AbuseDetected => e
    tries += 1
    reset_at = client.rate_limit&.resets_at
    wait = if e.respond_to?(:retry_after) && e.retry_after
            e.retry_after.to_i
            elsif reset_at
              [(reset_at - Time.now).ceil, 1].max
            else
              2 ** tries
            end
    warn "Rate limit/abuse detected; sleeping #{wait}s (try #{tries}/#{max_retries})"
    raise if tries >= max_retries
    sleep wait
    retry
  end
end