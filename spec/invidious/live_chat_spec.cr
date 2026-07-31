require "../spec_helper"

private def live_chat_fixture(name : String) : Hash(String, JSON::Any)
  path = File.join(__DIR__, "..", "fixtures", "live_chat", "#{name}.json")
  return JSON.parse(File.read(path)).as_h
end

Spectator.describe Invidious::LiveChat do
  # These fixtures are reduced, anonymized payloads captured from an active stream.
  it "extracts initial and mode-switch continuations from their response stages" do
    initial_response = live_chat_fixture("initial")
    chat_response = live_chat_fixture("response")

    expect(Invidious::LiveChat.extract_initial_continuation(initial_response)).to eq("top-chat-token")
    expect(Invidious::LiveChat.extract_live_continuation(chat_response)).to eq("live-chat-mode-token")
  end

  it "normalizes observed messages, notices, removals, and polling data" do
    result = Invidious::LiveChat.parse_response(live_chat_fixture("response"))

    expect(result.continuation).to eq("next-token")
    expect(result.timeout_ms).to eq(4321)
    expect(result.actions.size).to eq(3)

    message = result.actions[0]
    expect(message.action).to eq("add")
    expect(message.id).to eq("message-1")
    expect(message.kind).to eq("text")
    expect(message.author).to eq("Viewer")
    expect(message.message).to eq("Hello wave")
    expect(message.badges).to eq(["Member"])

    notice = result.actions[1]
    expect(notice.kind).to eq("engagement")
    expect(notice.message).to eq("Subscribers-only mode.")

    removal = result.actions[2]
    expect(removal.action).to eq("remove")
    expect(removal.id).to eq("message-0")
  end

  it "ignores malformed and unsupported chat items" do
    response = JSON.parse(<<-JSON).as_h
      {
        "continuationContents": {
          "liveChatContinuation": {
            "actions": [
              {"addChatItemAction": {"item": {"liveChatTextMessageRenderer": "invalid"}}},
              {"addChatItemAction": {"item": {"unsupportedRenderer": {"id": "ignored"}}}}
            ],
            "continuations": []
          }
        }
      }
      JSON

    expect(Invidious::LiveChat.parse_response(response).actions).to be_empty
  end

  it "clamps polling intervals" do
    response = live_chat_fixture("response")
    polling_data = response
      .dig("continuationContents", "liveChatContinuation", "continuations")
      .as_a[0]["invalidationContinuationData"]

    polling_data.as_h["timeoutMs"] = JSON::Any.new(100_i64)
    expect(Invidious::LiveChat.parse_response(response).timeout_ms).to eq(1000)

    polling_data.as_h["timeoutMs"] = JSON::Any.new(60_000_i64)
    expect(Invidious::LiveChat.parse_response(response).timeout_ms).to eq(30_000)
  end

  it "returns an ended response when live-chat contents are absent" do
    result = Invidious::LiveChat.parse_response({} of String => JSON::Any)

    expect(result.continuation).to be_nil
    expect(result.timeout_ms).to eq(10_000)
    expect(result.actions).to be_empty
  end
end
