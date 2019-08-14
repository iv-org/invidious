require "db"
require "./sqlite3/**"

module SQLite3
  DATE_FORMAT = "%F %H:%M:%S.%L"

  # :nodoc:
  TIME_ZONE = Time::Location::UTC
end
