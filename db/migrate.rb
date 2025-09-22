# Creates SQLite tables and indexes for repositories, users, pull_requests, reviews.
# Idempotent: uses if_not_exists and unique indexes on github_id to prevent duplicates.

require_relative "../config/database"
require "active_record"


# Create all tables in one go. Safe to run multiple times.

ActiveRecord::Schema.define do
  #repositories 
  
  create_table :repositories, if_not_exists: true do |t|
    t.integer :github_id, null: false
    t.string :name, null: false
    t.string :full_name, null: false
    t.string :html_url, null: false
    t.boolean :private, null: false, default: false
    t.boolean :archived, null: false, default: false
    t.timestamps
  end
  add_index :repositories, :github_id, unique: true
  add_index :repositories, :full_name, unique: true


  #users
  create_table :users, if_not_exists: true do |t|
    t.integer :github_id, null: false
    t.string :login, null: false
    t.string :html_url, null: false
    t.timestamps
  end
  add_index :users, :github_id, unique: true
  add_index :users, :login, unique: true


  #pull_requests
  create_table :pull_requests, if_not_exists: true do |t|
    t.integer :github_id, null: false
    t.integer :repository_id, null: false
    t.integer :number, null: false
    t.string :title
    t.datetime :updated_at_github
    t.datetime :closed_at
    t.datetime :merged_at
    t.integer :author_id    #user.id
    t.integer :additions
    t.integer :deletions
    t.integer :changed_files
    t.integer :commits_count
    t.string :state
    t.timestamps
  end
  add_index :pull_requests, :github_id, unique: true
  add_index :pull_requests, [:repository_id, :number], unique: true


  #reviews
  create_table :reviews, if_not_exists: true do |t|
    t.integer :github_id, null: false
    t.integer :pull_request_id, null: false
    t.integer :author_id    #user.id
    t.string :state
    t.datetime :submitted_at
    t.timestamps
  end
  add_index :reviews, :github_id, unique: true
  add_index :reviews, :pull_request_id
  add_index :reviews, :author_id
end