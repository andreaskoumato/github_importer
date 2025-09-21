require "active_record"
require "logger"
require "fileutils"

DB_FILE = File.expand_path("../db/github.sqlite3", __dir__) # Absolute path to SQLite3 database file
FileUtils.mkdir_p(File.dirname(DB_FILE))

ActiveRecord::Base.establish_connection(
  adapter: "sqlite3",
  database: DB_FILE
)

#  Print all SQL logs from ActiveRecord to the terminal
ActiveRecord::Base.logger = Logger.new(STDOUT) 