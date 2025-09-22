# import.rb — GitHub → SQLite importer
# - Calls GitHub API with Octokit
# - Saves Repositories, Pull Requests, Reviews, Users via ActiveRecord
# - Idempotent (upserts by github_id); resilient (retries on rate limits)

require "octokit"
require "time"
require_relative "app/models"

# Target scope comes from environment variables (simple, testable config)
ORG = ENV.fetch("ORG", "vercel") # GitHub organization to fetch data from
ONLY_REPO = ENV["ONLY_REPO"]    # If set, only fetch data for this repository (e.g. "vercel/next.js") to focus on a single repo

# Lazily create (and memoize) a GitHub API client using your token.
# ENV.fetch raises if GITHUB_TOKEN is missing, failing fast with a clear error.
def client
  @client ||= Octokit::Client.new(access_token: ENV.fetch("GITHUB_TOKEN"))
end


# Small wrapper that executes a block and retries on rate-limit errors. (Bonus)
# - yield runs the given block immediately (synchronously).
# - on TooManyRequests/AbuseDetected: compute a wait time, sleep, and retry a few times.
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

# Upsert Helpers ------------------------------------------------------
# Each helper:
# - finds an existing record by github_id OR initializes a new one
# - assigns/updates fields
# - saves with save! (raise if invalid)
# This makes the importer idempotent and safe to re-run.

def upsert_user!(gh_user)
  return nil unless gh_user
  User.find_or_initialize_by(github_id: gh_user[:id]).tap do |u|
    u.login = gh_user.login
    u.html_url = gh_user.html_url
    u.save!
  end
end

def upsert_repo!(gh_repo)
  Repository.find_or_initialize_by(github_id: gh_repo[:id]).tap do |r|
    r.name = gh_repo[:name]
    r.full_name = gh_repo[:full_name]
    r.html_url = gh_repo[:html_url]
    r.private = gh_repo[:private]
    r.archived = gh_repo[:archived]
    r.save!
  end
end

def upsert_pr!(repo, full_pr)
  author = upsert_user!(full_pr[:user]) # ensure author exists; capture local id
  PullRequest.find_or_initialize_by(github_id: full_pr[:id]).tap do |p|
    p.repository_id = repo.id           # local FK to repositories.id
    p.number = full_pr[:number]         # human PR number within the repo
    p.title = full_pr[:title]
    p.state = full_pr[:state]
    p.updated_at_github = full_pr[:updated_at]
    p.closed_at = full_pr[:closed_at]
    p.merged_at = full_pr[:merged_at]
    p.author_id = author&.id            # local FK to users.id (may be nil)
    p.additions = full_pr[:additions]
    p.deletions = full_pr[:deletions]
    p.changed_files = full_pr[:changed_files]
    p.commits_count = full_pr[:commits]
    p.save!
  end
end

def upsert_review!(pr_record, rv)
  reviewer = upsert_user!(rv[:user])
  Review.find_or_initialize_by(github_id: rv[:id]).tap do |r|
    r.pull_request_id = pr_record.id
    r.author_id = reviewer&.id
    r.state = rv[:state]
    r.submitted_at = rv[:submitted_at]
    r.save!
  end
end

# Fetch and persist all reviews for a single PR.
def import_reviews!(repo_full_name, pr_number, pr_record)
  reviews = with_retries { client.pull_request_reviews(repo_full_name, pr_number, per_page: 100) }
  reviews.each { |rv| upsert_review!(pr_record, rv) }
end

# Fetch and persist (paged) PRs for a single repo; for each PR, fetch details + reviews.
def import_prs!(repo)
  puts "Fetching PRs for #{repo.full_name}..."
  page = 1
  loop do
    prs = with_retries { client.pull_requests(repo.full_name, state: "all", per_page: 100, page: page) }
    break if prs.empty?

    prs.each do |pr|
      full = with_retries { client.pull_request(repo.full_name, pr[:number]) } # details (stats + timestamps)
      pr_rec = upsert_pr!(repo, full)
      import_reviews!(repo.full_name, pr[:number], PullRequest.find_by!(github_id: full[:id]))
    end

    page += 1
  end
end

# Entrypoint -----------------------------------------------------

if ONLY_REPO
  # Fast path for a single repository (e.g., vercel/next.js)
  gh_repo = with_retries { client.repo(ONLY_REPO) }
  repo = upsert_repo!(gh_repo)
  import_prs!(repo)
else
  # Default path: iterate all public repos in the org (paginated)
  puts "Fetching repos for org=#{ORG}..."
  page = 1
  loop do
    repos = with_retries { client.org_repos(ORG, type: "public", per_page: 100, page: page) }
    break if repos.empty?

    repos.each do |gh_repo|
      repo = upsert_repo!(gh_repo)
      next if repo.private # extra guard; org call is already type: "public"
      import_prs!(repo)
    end
    page += 1
  end
end

puts "Done."