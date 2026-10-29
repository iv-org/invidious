require "../../spec_helper"

Spectator.describe Invidious::Helpers::Tokens do
  describe ".sign_token" do
    it "correctly signs a given hash" do
      token = {
        "session" => "v1:AAAAAAAAAAAAAAAAAAAAAAAAAAAAAA",
        "expires" => 1554680038,
        "scopes"  => [
          ":notifications",
          ":subscriptions/*",
          "GET:tokens*",
        ],
        "signature" => "f__2hS20th8pALF305PJFK-D2aVtvefNnQheILHD2vU=",
      }
      expect(Invidious::Helpers::Tokens.sign_token("SECRET_KEY", token)).to eq(token["signature"])

      token = {
        "session"   => "v1:AAAAAAAAAAAAAAAAAAAAAAAAAAAAAA",
        "scopes"    => [":notifications", "POST:subscriptions/*"],
        "signature" => "fNvXoT0MRAL9eE6lTE33CEg8HitYJDOL9a22rSN2Ihg=",
      }
      expect(Invidious::Helpers::Tokens.sign_token("SECRET_KEY", token)).to eq(token["signature"])
    end
  end
end
