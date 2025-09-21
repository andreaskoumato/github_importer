require_relative "../config/database"
require "active_record"

class Repository < ActiveRecord::Base
  has_many :pull_requests
end

class User < ActiveRecord::Base
  has_many :authered_pull_requests, class_name: "PullRequest", foreign_key: "author_id"
  has_many :authered_reviews, class_name: "Review", foreign_key: "author_id"
end

class PullRequest < ActiveRecord::Base
  belongs_to :repository
  belongs_to :author, class_name: "User", optional: true
  has_many :reviews
end

class Review < ActiveRecord::Base
  belongs_to :pull_request
  belongs_to :author, class_name: "User", optional: true
end
