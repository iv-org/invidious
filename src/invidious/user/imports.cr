require "csv"

struct Invidious::User
  module Import
    extend self

    # Parse a youtube CSV subscription file
    def parse_subscription_export_csv(csv_content : String)
      rows = CSV.new(csv_content, headers: true)
      subscriptions = Array(String).new

      # Counter to limit the amount of imports.
      # This is intended to prevent DoS.
      row_counter = 0

      rows.each do |row|
        # Limit to 1200
        row_counter += 1
        break if row_counter > 1_200

        # Channel ID is the first column in the csv export we can't use the header
        # name, because the header name is localized depending on the
        # language the user has set on their account
        channel_id = row[0].strip

        next if channel_id.empty?
        subscriptions << channel_id
      end

      return subscriptions
    end
  end
end
