require "../../parsers_helper.cr"

def related_collaborators_fixture
  JSON.parse(File.read(File.join(__DIR__, "../../fixtures/related_collaborators.json")))
end

Spectator.describe "parse_related_video authors" do
  it "preserves the legacy single-author fields and string-valued cache" do
    related = JSON.parse(%({"videoId":"single","title":{"simpleText":"Single"},
      "shortBylineText":{"runs":[{"text":"Author","navigationEndpoint":{"browseEndpoint":{"browseId":"UC-single"}}}]}}))
    video = Invidious::Videos::Parser.parse_related_video(related).not_nil!

    expect(video["author"]).to eq("Author")
    expect(video["ucid"]).to eq("UC-single")
    expect(video.values.all?(&.as_s?)).to be_true
  end

  it "extracts each collaborator without relying on the localized dialog title" do
    video = Invidious::Videos::Parser.parse_related_video(related_collaborators_fixture).not_nil!
    authors = JSON.parse(video["author_channels"].as_s).as_a

    expect(video["author"]).to eq("Alpha & Friends et Beta <Live>")
    expect(video["ucid"]).to eq("")
    expect(authors.map(&.["name"].as_s)).to eq(["Alpha & Friends", "Beta <Live>"])
    expect(authors.map(&.["ucid"].as_s)).to eq(["UC-alpha", "UC-beta"])
    expect(authors.map(&.["verified"].as_s)).to eq(["true", "false"])
    expect(video.values.all?(&.as_s?)).to be_true
  end

  it "finds all directly linked runs including a link after an unlinked label" do
    related = JSON.parse(%({"videoId":"flat","title":{"simpleText":"Flat"},
      "longBylineText":{"runs":[{"text":"Featuring "},
        {"text":"First","navigationEndpoint":{"browseEndpoint":{"browseId":"UC-first"}}},
        {"text":" and "},
        {"text":"Second","navigationEndpoint":{"browseEndpoint":{"browseId":"UC-second"}}}]}}))
    video = Invidious::Videos::Parser.parse_related_video(related).not_nil!
    authors = JSON.parse(video["author_channels"].as_s).as_a

    expect(authors.map(&.["ucid"].as_s)).to eq(["UC-first", "UC-second"])
    expect(video["author"]).to eq("Featuring ")
    expect(video["ucid"]).to eq("")
  end

  it "retains a collaborator name without inventing a missing channel destination" do
    related = related_collaborators_fixture
    item = related.dig("shortBylineText", "runs", 0, "navigationEndpoint", "showDialogCommand",
      "panelLoadingStrategy", "inlineContent", "dialogViewModel", "customContent", "listViewModel", "listItems", 1)
    item["listItemViewModel"].as_h.delete("rendererContext")
    video = Invidious::Videos::Parser.parse_related_video(related).not_nil!
    authors = JSON.parse(video["author_channels"].as_s).as_a

    expect(authors[1]["name"]).to eq("Beta <Live>")
    expect(authors[1]["ucid"]).to eq("")
  end

  it "keeps an unlinked author when no channel data is available" do
    related = JSON.parse(%({"videoId":"unlinked","title":{"simpleText":"Unlinked"},
      "shortBylineText":{"runs":[{"text":"Unlinked author"}]}}))
    video = Invidious::Videos::Parser.parse_related_video(related).not_nil!

    expect(video["author"]).to eq("Unlinked author")
    expect(video["ucid"]).to eq("")
  end
end
