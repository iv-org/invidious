require "../../parsers_helper"
require "../../../src/invidious/helpers/helpers"
require "../../../src/invidious/helpers/i18next"
require "../../../src/invidious/helpers/i18n"
require "../../../src/invidious/yt_backend/youtube_api"
require "../../../src/invidious/frontend/comments_youtube"
require "../../../src/invidious/comments/youtube"

Spectator.describe Invidious::Comments do
  describe ".parse_youtube" do
    it "shows a message when comments are disabled" do
      response = JSON.parse({
        "onResponseReceivedEndpoints" => [
          {
            "reloadContinuationItemsCommand" => {
              "slot"              => "RELOAD_CONTINUATION_SLOT_HEADER",
              "continuationItems" => [
                {
                  "commentsHeaderRenderer" => {
                    "countText" => {"simpleText" => "0 Comments"},
                  },
                },
              ],
            },
          },
          {
            "reloadContinuationItemsCommand" => {
              "slot" => "RELOAD_CONTINUATION_SLOT_BODY",
            },
          },
        ],
      }.to_json)

      parsed = JSON.parse(Invidious::Comments.parse_youtube("video-id", response, "html", "en-US", false))

      expect(parsed["contentHtml"].as_s).to contain("Comments are turned off.")
      expect(parsed["commentCount"].as_i).to eq(0)
    end

    it "marks disabled comments in JSON responses" do
      response = JSON.parse({
        "onResponseReceivedEndpoints" => [
          {
            "reloadContinuationItemsCommand" => {
              "slot" => "RELOAD_CONTINUATION_SLOT_BODY",
            },
          },
        ],
      }.to_json)

      parsed = JSON.parse(Invidious::Comments.parse_youtube("video-id", response, "json", "en-US", false))

      expect(parsed["comments"].as_a).to be_empty
      expect(parsed["commentsDisabled"].as_bool).to be_true
    end
  end
end
