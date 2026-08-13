require "../../parsers_helper"

Spectator.describe "strip_url_trailing_punctuation" do
  it "strips trailing punctuation from URLs" do
    expect(strip_url_trailing_punctuation("https://example.com.")).to eq("https://example.com")
    expect(strip_url_trailing_punctuation("https://example.com,")).to eq("https://example.com")
    expect(strip_url_trailing_punctuation("https://example.com...")).to eq("https://example.com")
    expect(strip_url_trailing_punctuation("https://example.com/page)!?")).to eq("https://example.com/page")
  end

  it "keeps URLs without trailing punctuation untouched" do
    expect(strip_url_trailing_punctuation("https://example.com")).to eq("https://example.com")
    expect(strip_url_trailing_punctuation("https://example.com/a.b?c=d,e#f")).to eq("https://example.com/a.b?c=d,e#f")
  end

  it "keeps balanced closing parentheses" do
    expect(strip_url_trailing_punctuation("https://en.wikipedia.org/wiki/Crystal_(programming_language)"))
      .to eq("https://en.wikipedia.org/wiki/Crystal_(programming_language)")

    # Only the unmatched parenthesis is stripped
    expect(strip_url_trailing_punctuation("https://en.wikipedia.org/wiki/Crystal_(programming_language))"))
      .to eq("https://en.wikipedia.org/wiki/Crystal_(programming_language)")
  end
end

Spectator.describe "text_to_parsed_content" do
  it "parses text without URLs" do
    runs = text_to_parsed_content("Hello world").dig("runs").as_a

    expect(runs.size).to eq(1)
    expect(runs[0].dig("text").as_s).to eq("Hello world\n")
  end

  it "auto-links a bare URL" do
    runs = text_to_parsed_content("https://example.com").dig("runs").as_a

    expect(runs.size).to eq(3)
    expect(runs[0].dig("text").as_s).to eq("")
    expect(runs[1].dig("text").as_s).to eq("https://example.com")
    expect(runs[1].dig("navigationEndpoint", "urlEndpoint", "url").as_s).to eq("https://example.com")
    expect(runs[2].dig("text").as_s).to eq("\n")
  end

  it "excludes sentence punctuation from auto-linked URLs" do
    runs = text_to_parsed_content("Check out https://example.com. Thanks!").dig("runs").as_a

    expect(runs.size).to eq(3)
    expect(runs[0].dig("text").as_s).to eq("Check out ")
    expect(runs[1].dig("navigationEndpoint", "urlEndpoint", "url").as_s).to eq("https://example.com")
    expect(runs[2].dig("text").as_s).to eq(". Thanks!\n")
  end

  it "excludes the closing parenthesis of enclosing text" do
    runs = text_to_parsed_content("(visit my website at https://example.com)").dig("runs").as_a

    expect(runs.size).to eq(3)
    expect(runs[0].dig("text").as_s).to eq("(visit my website at ")
    expect(runs[1].dig("navigationEndpoint", "urlEndpoint", "url").as_s).to eq("https://example.com")
    expect(runs[2].dig("text").as_s).to eq(")\n")
  end

  it "keeps URLs containing balanced parentheses intact" do
    runs = text_to_parsed_content("(see https://en.wikipedia.org/wiki/Crystal_(programming_language))").dig("runs").as_a

    expect(runs.size).to eq(3)
    expect(runs[1].dig("navigationEndpoint", "urlEndpoint", "url").as_s)
      .to eq("https://en.wikipedia.org/wiki/Crystal_(programming_language)")
    expect(runs[2].dig("text").as_s).to eq(")\n")
  end

  it "keeps punctuation inside URLs" do
    runs = text_to_parsed_content("Docs: https://example.com/a.b?c=d,e#f! Read").dig("runs").as_a

    expect(runs.size).to eq(3)
    expect(runs[1].dig("navigationEndpoint", "urlEndpoint", "url").as_s).to eq("https://example.com/a.b?c=d,e#f")
    expect(runs[2].dig("text").as_s).to eq("! Read\n")
  end

  it "does not include angle brackets in auto-linked URLs" do
    runs = text_to_parsed_content("<https://example.com>").dig("runs").as_a

    expect(runs.size).to eq(3)
    expect(runs[0].dig("text").as_s).to eq("<")
    expect(runs[1].dig("navigationEndpoint", "urlEndpoint", "url").as_s).to eq("https://example.com")
    expect(runs[2].dig("text").as_s).to eq(">\n")
  end

  it "auto-links multiple URLs on the same line" do
    runs = text_to_parsed_content("See https://a.example, then https://b.example.").dig("runs").as_a

    expect(runs.size).to eq(5)
    expect(runs[0].dig("text").as_s).to eq("See ")
    expect(runs[1].dig("navigationEndpoint", "urlEndpoint", "url").as_s).to eq("https://a.example")
    expect(runs[2].dig("text").as_s).to eq(", then ")
    expect(runs[3].dig("navigationEndpoint", "urlEndpoint", "url").as_s).to eq("https://b.example")
    expect(runs[4].dig("text").as_s).to eq(".\n")
  end

  it "keeps the text surrounding a repeated URL" do
    runs = text_to_parsed_content("https://example.com and https://example.com.").dig("runs").as_a

    expect(runs.size).to eq(5)
    expect(runs[1].dig("navigationEndpoint", "urlEndpoint", "url").as_s).to eq("https://example.com")
    expect(runs[2].dig("text").as_s).to eq(" and ")
    expect(runs[3].dig("navigationEndpoint", "urlEndpoint", "url").as_s).to eq("https://example.com")
    expect(runs[4].dig("text").as_s).to eq(".\n")
  end

  it "handles URLs on multiple lines" do
    runs = text_to_parsed_content("Line one https://example.com,\nLine two").dig("runs").as_a

    expect(runs.size).to eq(4)
    expect(runs[0].dig("text").as_s).to eq("Line one ")
    expect(runs[1].dig("navigationEndpoint", "urlEndpoint", "url").as_s).to eq("https://example.com")
    expect(runs[2].dig("text").as_s).to eq(",\n")
    expect(runs[3].dig("text").as_s).to eq("Line two\n")
  end
end
