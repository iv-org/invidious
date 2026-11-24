require "http"
require "socket"
require "spectator"
require "../../src/invidious/helpers/crystal_class_overrides"

Spectator.describe HTTP::Client do
  describe "#disable_reconnect" do
    it "never opens a new (direct) connection once disabled" do
      server = TCPServer.new("127.0.0.1", 0)
      accepted = 0
      spawn do
        while socket = server.accept?
          accepted += 1
          socket.close
        end
      end

      client = HTTP::Client.new("127.0.0.1", server.local_address.port)
      client.disable_reconnect

      expect { client.get("/") }.to raise_error(Exception, /cannot be reconnected/)
      Fiber.yield
      expect(accepted).to eq(0)
    ensure
      server.try &.close
    end
  end
end
