require "csv"

def parse_subscription_export_csv(csv_content : String)
  rows = CSV.new(csv_content, headers: true)
  subscriptions = Array(String).new

  rows.each do |row|
    # Channel ID is the first column in the csv export we can't use the header
    # name, because the header name is localized depending on the
    # language the user has set on their account
    channel_id = row[0].strip

    next if channel_id.empty?

    subscriptions << channel_id
  end

  subscriptions
end
