require "../../parsers_helper.cr"
require "ecr"
require "xml"

def render_related_video_authors(rv : Hash(String, String))
  ECR.render "src/invidious/views/components/related_video_authors.ecr"
end

Spectator.describe "related video author links" do
  it "renders cached single-author records without collaborator metadata" do
    html = render_related_video_authors({"author" => "Legacy & Author", "ucid" => "UC-legacy", "author_verified" => "true"})
    document = XML.parse_html(html)

    expect(document.xpath_nodes("//a").size).to eq(1)
    expect(document.xpath_node("//a").not_nil!["href"]).to eq("/channel/UC-legacy")
    expect(document.xpath_node("//a").not_nil!.content).to contain("Legacy & Author")
    expect(document.xpath_nodes("//i").size).to eq(1)
  end

  it "renders every collaborator and escapes names and destinations" do
    authors = [
      {"name" => "Alpha & Friends", "ucid" => "UC-alpha", "verified" => "true"},
      {"name" => "<script>Beta</script>", "ucid" => "UC-\"quoted", "verified" => "false"},
      {"name" => "Unlinked <Author>", "ucid" => "", "verified" => "false"},
    ]
    html = render_related_video_authors({"author" => "Combined", "ucid" => "", "author_channels" => authors.to_json})
    document = XML.parse_html(html)
    links = document.xpath_nodes("//a")

    expect(links.size).to eq(2)
    expect(links[0]["href"]).to eq("/channel/UC-alpha")
    expect(links[1]["href"]).to eq("/channel/UC-\"quoted")
    expect(links[1].content.strip).to eq("<script>Beta</script>")
    expect(document.xpath_nodes("//script").size).to eq(0)
    expect(document.xpath_nodes("//i").size).to eq(1)
    expect(document.content).to contain("Unlinked <Author>")
  end

  it "renders links from a parsed localized dialog through the string-valued cache" do
    related = JSON.parse(File.read(File.join(__DIR__, "../../fixtures/related_collaborators.json")))
    video = Invidious::Videos::Parser.parse_related_video(related).not_nil!
    cached = JSON.parse(video.to_json).as_h.transform_values &.as_s
    document = XML.parse_html(render_related_video_authors(cached))
    links = document.xpath_nodes("//a")

    expect(links.map { |link| link["href"] }).to eq(["/channel/UC-alpha", "/channel/UC-beta"])
    expect(links[1].content.strip).to eq("Beta <Live>")
  end

  it "falls back to an escaped unlinked label when no channels were extracted" do
    html = render_related_video_authors({"author" => "<Legacy>", "ucid" => "", "author_channels" => "[]"})
    document = XML.parse_html(html)

    expect(document.xpath_nodes("//a").size).to eq(0)
    expect(document.content).to contain("<Legacy>")
  end
end
