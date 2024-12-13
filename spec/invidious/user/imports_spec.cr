require "spectator"
require "../../../src/invidious/user/imports"

Spectator.configure do |config|
  config.fail_blank
  config.randomize
end

def csv_sample
  return <<-CSV
  Kanal-ID,Kanal-URL,Kanaltitel
  UC0hHW5Y08ggq-9kbrGgWj0A,http://www.youtube.com/channel/UC0hHW5Y08ggq-9kbrGgWj0A,Matias Marolla
  UC0vBXGSyV14uvJ4hECDOl0Q,http://www.youtube.com/channel/UC0vBXGSyV14uvJ4hECDOl0Q,Techquickie
  UC1sELGmy5jp5fQUugmuYlXQ,http://www.youtube.com/channel/UC1sELGmy5jp5fQUugmuYlXQ,Minecraft
  UC9kFnwdCRrX7oTjqKd6-tiQ,http://www.youtube.com/channel/UC9kFnwdCRrX7oTjqKd6-tiQ,LUMOX - Topic
  UCBa659QWEk1AI4Tg--mrJ2A,http://www.youtube.com/channel/UCBa659QWEk1AI4Tg--mrJ2A,Tom Scott
  UCGu6_XQ64rXPR6nuitMQE_A,http://www.youtube.com/channel/UCGu6_XQ64rXPR6nuitMQE_A,Callcenter Fun
  UCGwu0nbY2wSkW8N-cghnLpA,http://www.youtube.com/channel/UCGwu0nbY2wSkW8N-cghnLpA,Jaiden Animations
  UCQ0OvZ54pCFZwsKxbltg_tg,http://www.youtube.com/channel/UCQ0OvZ54pCFZwsKxbltg_tg,Methos
  UCRE6itj4Jte4manQEu3Y7OA,http://www.youtube.com/channel/UCRE6itj4Jte4manQEu3Y7OA,Chipflake
  UCRLc6zsv_d0OEBO8OOkz-DA,http://www.youtube.com/channel/UCRLc6zsv_d0OEBO8OOkz-DA,Kegy
  UCSl5Uxu2LyaoAoMMGp6oTJA,http://www.youtube.com/channel/UCSl5Uxu2LyaoAoMMGp6oTJA,Atomic Shrimp
  UCXuqSBlHAE6Xw-yeJA0Tunw,http://www.youtube.com/channel/UCXuqSBlHAE6Xw-yeJA0Tunw,Linus Tech Tips
  UCZ5XnGb-3t7jCkXdawN2tkA,http://www.youtube.com/channel/UCZ5XnGb-3t7jCkXdawN2tkA,Discord
  CSV
end

Spectator.describe Invidious::User::Import do
  it "imports CSV" do
    subscriptions = Invidious::User::Import.parse_subscription_export_csv(csv_sample)

    expect(subscriptions).to be_an(Array(String))
    expect(subscriptions.size).to eq(13)

    expect(subscriptions).to contain_exactly(
      "UC0hHW5Y08ggq-9kbrGgWj0A",
      "UC0vBXGSyV14uvJ4hECDOl0Q",
      "UC1sELGmy5jp5fQUugmuYlXQ",
      "UC9kFnwdCRrX7oTjqKd6-tiQ",
      "UCBa659QWEk1AI4Tg--mrJ2A",
      "UCGu6_XQ64rXPR6nuitMQE_A",
      "UCGwu0nbY2wSkW8N-cghnLpA",
      "UCQ0OvZ54pCFZwsKxbltg_tg",
      "UCRE6itj4Jte4manQEu3Y7OA",
      "UCRLc6zsv_d0OEBO8OOkz-DA",
      "UCSl5Uxu2LyaoAoMMGp6oTJA",
      "UCXuqSBlHAE6Xw-yeJA0Tunw",
      "UCZ5XnGb-3t7jCkXdawN2tkA",
    ).in_order
  end
end
