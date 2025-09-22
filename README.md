# GitHub Importer

This project is a small Ruby app that imports data from the GitHub API into a local SQLite database.  
It focuses on repositories, pull requests, users, and reviews.  

The challenge is to show how to:  
- Use Ruby and ActiveRecord with migrations and models  
- Call the GitHub API with Octokit  
- Handle rate limits and retries  
- Save normalized data in a relational database  

---
### Prerequisites
- Ruby >= 3.0 (tested on 3.2.2)
- Bundler
- SQLite3

## Setup

### 1. Clone and install dependencies
```bash
git clone https://github.com/andreaskoumato/github_importer.git
cd github_importer
bundle install
```

### 2. Configure environment variables
You need a GitHub personal access token. Create one here: https://github.com/settings/tokens

Export it in your shell:
```bash
export GITHUB_TOKEN=your_token_here
```

Optional variables:
```bash
export ORG=vercel              # GitHub org to fetch (default: vercel)
export ONLY_REPO=vercel/next.js # Limit to a single repo (optional)
```

### 3. Run database migrations
```bash
bundle exec ruby db/migrate.rb
```

This creates the following tables:  
- `repositories`  
- `users`  
- `pull_requests`  
- `reviews`  

### 4. Run the importer
```bash
bundle exec ruby import.rb
```

---

## Database Schema

- **Repository**
  - github_id, name, full_name, html_url, private, archived

- **User**
  - github_id, login, html_url

- **PullRequest**
  - github_id, repository_id, number, title, state, timestamps
  - author_id (FK → users)
  - additions, deletions, changed_files, commits_count

- **Review**
  - github_id, pull_request_id, author_id
  - state, submitted_at

All tables include `t.timestamps` (created_at, updated_at).

---

## How It Works

- The script uses **Octokit** to talk to GitHub.  
- Data is saved with **ActiveRecord** models.  
- Helper methods (`upsert_user!`, `upsert_repo!`, etc.) ensure data is inserted or updated.  
- **with_retries** wraps API calls to handle GitHub rate limits automatically.  
- The script can import either:
  - All repos for an org (`ORG=vercel`), or
  - A single repo (`ONLY_REPO=vercel/next.js`).

---

## Notes on Runtime

- Large repos like `vercel/next.js` have thousands of pull requests and reviews.  
- Importing everything can take a long time and hit GitHub API rate limits.  
- The script is **idempotent**: you can stop anytime (Ctrl+C) and restart later.  
  Existing rows will just be updated, not duplicated.  

---

## Example SQL Queries

After running, open the database:
```bash
sqlite3 db/github.sqlite3
.tables
SELECT COUNT(*) FROM repositories;
SELECT COUNT(*) FROM users;
SELECT COUNT(*) FROM pull_requests;
SELECT COUNT(*) FROM reviews;
```

---

## Trade-offs / Design Choices

- Focused on **correctness and resilience** over speed.  
- Uses retries and idempotency to ensure robustness.  
- Not optimized for bulk inserts due to time constraints.  
- Intended as a clear demonstration of a working data pipeline, not production-scale ingestion.  

---

## Done

This completes the importer.  
It demonstrates API integration, data modeling, and persistence with Ruby + ActiveRecord.  

## What I learned

This challenge helped me practice Ruby, ActiveRecord, and working with APIs. It was my first time coding in Ruby, so I focused on writing clean, working code and documenting it clearly.