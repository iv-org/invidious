class Invidious::Jobs::NotificationJob < Invidious::Jobs::BaseJob
  private getter connection_channel : Channel({Bool, Channel(PQ::Notification)})
  private getter pg_url : URI

  def initialize(@connection_channel, @pg_url)
  end

  def begin
    connections = [] of Channel(PQ::Notification)

    PG.connect_listen(pg_url, "notifications") { |event| connections.each(&.send(event)) }

    loop do
      action, connection = connection_channel.receive

      case action
      when true
        connections << connection
      when false
        connections.delete(connection)
      end
    end
  end
end
