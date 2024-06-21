require "../env_helper"
require "kilt"

Spectator.describe "error_redirect_helper" do
  it "shows next steps on embed page errors" do
    current_url = "/embed/IeQT18gaB-c?si=YxBQzH-GBSTS4vBS"
    test_env = test_env current_url
    test_env.set "current_page", current_url

    html = error_redirect_helper(test_env)
    expect(html).to eq "<p style=\"margin-bottom: 4px;\">After which you should try to: </p>\n<ul>\n  \n    <li>\n      <a href=\"/embed/IeQT18gaB-c?si=YxBQzH-GBSTS4vBS\">Refresh</a>\n    </li>\n  \n    <li>\n      <a href=\"/redirect?referer=/embed/IeQT18gaB-c?si=YxBQzH-GBSTS4vBS\">Switch Invidious Instance</a>\n    </li>\n  \n    <li>\n      <a href=\"https://youtube.com/embed/IeQT18gaB-c?si=YxBQzH-GBSTS4vBS\">Go to YouTube</a>\n    </li>\n  \n    <li>\n      <a href=\"/watch?v=IeQT18gaB-c?si=YxBQzH-GBSTS4vBS\">Open in new page</a>\n    </li>\n  \n</ul>\n"
  end

  it "shows next steps for watch pages" do
    current_url = "/watch?v=IeQT18gaB-c?si=YxBQzH-GBSTS4vBS"
    test_env = test_env current_url
    test_env.set "current_page", current_url

    html = error_redirect_helper(test_env)
    expect(html).to eq "<p style=\"margin-bottom: 4px;\">After which you should try to: </p>\n<ul>\n  \n    <li>\n      <a href=\"/watch?v=IeQT18gaB-c?si=YxBQzH-GBSTS4vBS\">Refresh</a>\n    </li>\n  \n    <li>\n      <a href=\"/redirect?referer=/watch?v=IeQT18gaB-c?si=YxBQzH-GBSTS4vBS\">Switch Invidious Instance</a>\n    </li>\n  \n    <li>\n      <a href=\"https://youtube.com/watch?v=IeQT18gaB-c?si=YxBQzH-GBSTS4vBS\">Go to YouTube</a>\n    </li>\n  \n</ul>\n"
  end

  it "returns an empty string for unknown pages" do
    current_url = "/foo"
    test_env = test_env current_url
    test_env.set "current_page", current_url

    html = error_redirect_helper(test_env)
    expect(html).to eq ""
  end
end
