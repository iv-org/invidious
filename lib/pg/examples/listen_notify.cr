require "../src/pg"

PG.connect_listen("postgres:///", "a", "b") do |n| # connect and  listen on "a" and "b"
  puts "    got: #{n.payload} on #{n.channel}"     # print notifications as they come in
end

PG_DB = DB.open("postgres:///")                       # make a normal connection
spawn do                                              # spawn a coroutine
  10.times do |i|                                     #
    chan = rand > 0.5 ? "a" : "b"                     # pick a channel
    puts "sending: #{i}"                              # prints always before "got:"
    PG_DB.exec("SELECT pg_notify($1, $2)", [chan, i]) # send notification
    puts "   sent: #{i}"                              # may print before or after "got:"
    sleep 1
  end
end

sleep 6 #                                          # wait a bit before exiting

# Example output. Ordering and channels will vary.
#
# sending: 0
#    sent: 0
#     got: 0 on a
# sending: 1
#     got: 1 on a
#    sent: 1
# sending: 2
#    sent: 2
#     got: 2 on a
# sending: 3
#    sent: 3
#     got: 3 on b
# sending: 4
#    sent: 4
#     got: 4 on b
# sending: 5
#     got: 5 on a
#    sent: 5
