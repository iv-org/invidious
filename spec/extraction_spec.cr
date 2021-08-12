require "pg" # Required for DB::Serializable
require "spec"

# Required for initializing DB::Serializable objects with NamedTuples
require "../src/invidious/helpers/macros"

# Renderer structs
require "../src/invidious/data_structs/youtube/base"
require "../src/invidious/data_structs/youtube/renderers/*"
require "../src/invidious/data_structs/youtube/videos" # Category obj requires Video struct.

require "../src/invidious/helpers/extractors.cr"
require "./item_jsons/*"

describe YouTubeStructs::VideoRenderer do
  it "It is able to extract a 'standard' videoRenderer without missing information" do
    video = extract_item(JSON.parse(VIDEO_RENDERER_EXAMPLES[0])).as(YouTubeStructs::VideoRenderer)

    video.author.should(eq("Kurzgesagt – In a Nutshell"))
    video.description_html.should(eq(""))
    video.id.should(eq("E1KkQrFEl2I"))
    video.length_seconds.should(eq(665))
    video.live_now.should(eq(false))
    video.paid.should(eq(false))
    video.premiere_timestamp.should(eq(nil))
    video.premium.should(eq(false))

    # Invidious uses the current time (UTC) to compute a timestamp
    # from YouTube's relative upload dates on renderers.
    video.published.not_nil!.to_s("%Y-%m-%d").should(eq((Time.utc - 9.months).to_s("%Y-%m-%d")))

    video.title.should(eq("How Large Can a Bacteria get? Life & Size 3"))
    video.ucid.should(eq("UCsXVk37bltHxD1rDPwtNM8Q"))
    video.views.should(eq(7324534))
  end
end

describe YouTubeStructs::ChannelRenderer do
  it "It is able to extract a 'standard' channelRenderer without missing information" do
    channel = extract_item(JSON.parse(CHANNEL_RENDERER_EXAMPLES[0])).as(YouTubeStructs::ChannelRenderer)

    channel.author.should(eq("Kurzgesagt – In a Nutshell"))
    channel.author_thumbnail.should(eq("//yt3.ggpht.com/ytc/AKedOLRvMf1ZTTCnC5Wc0EGOVPyrdyvfvs20vtdTUxz_vQ=s88-c-k-c0x00ffffff-no-rj-mo"))
    channel.auto_generated.should(eq(false))
    channel.description_html.should(eq("Videos explaining things with optimistic nihilism. We are a small team who want to make science look beautiful. Because it is ..."))
    channel.subscriber_count.should(eq(15700000))
    channel.ucid.should(eq("UCsXVk37bltHxD1rDPwtNM8Q"))
    channel.video_count.should(eq(144))
  end

  it "It is able to extract a channelRenderer without subscription information" do
    channel = extract_item(JSON.parse(CHANNEL_RENDERER_EXAMPLES[1])).as(YouTubeStructs::ChannelRenderer)

    channel.author.should(eq("Langfocus"))
    channel.author_thumbnail.should(eq("//yt3.ggpht.com/ytc/AKedOLRvsTYz7nlOWrGLc1GzlV96kXxY1Q9IE1KzqbXa3g=s88-c-k-c0x00ffffff-no-rj-mo"))
    channel.auto_generated.should(eq(false))
    channel.description_html.should(eq("Sharing my passion for languages and reaching out into the wider world."))
    channel.subscriber_count.should(eq(0)) # Not accurate. This value should ideally be nil in this case
    channel.ucid.should(eq("UCNhX3WQEkraW3VHPyup8jkQ"))
    channel.video_count.should(eq(165))
  end
end

describe YouTubeStructs::PlaylistRenderer do
  it "It is able to extract a 'standard' playlistRenderer without missing information" do
    playlist = extract_item(JSON.parse(PLAYLIST_RENDERER_EXAMPLES[0])).as(YouTubeStructs::PlaylistRenderer)

    playlist.author.should(eq("Kurzgesagt – In a Nutshell"))
    playlist.id.should(eq("PLFs4vir_WsTwEd-nJgVJCZPNL3HALHHpF"))
    playlist.thumbnail.should(eq("https://i.ytimg.com/vi/0FH9cgRhQ-k/hqdefault.jpg?sqp=-oaymwEWCKgBEF5IWvKriqkDCQgBFQAAiEIYAQ==&rs=AOn4CLD9giG-6BICfsfD6p8l0OxjPEqiPg"))
    playlist.title.should(eq("The Universe and Space stuff"))
    playlist.ucid.should(eq("UCsXVk37bltHxD1rDPwtNM8Q"))
    playlist.video_count.should(eq(32))
    playlist.videos.should(eq([
      {title:          "The Largest Black Hole in the Universe - Size Comparison",
       id:             "0FH9cgRhQ-k",
       length_seconds: 824},

      {title:          "How To Terraform Venus (Quickly)",
       id:             "G-WO-z-QuWI",
       length_seconds: 768},
    ]))
  end

  it "It is able to extract a playlistRenderer located in a grid, and has no missing information" do
    # We'll add the channel name and UCID as a fallback
    # as the author information just isn't returned by InnerTube in a gridPlaylistRenderer.
    playlist = extract_item(
      JSON.parse(PLAYLIST_RENDERER_EXAMPLES[1]),
      "Kurzgesagt – In a Nutshell",
      "UCsXVk37bltHxD1rDPwtNM8Q"
    ).as(YouTubeStructs::PlaylistRenderer)

    playlist.author.should(eq("Kurzgesagt – In a Nutshell"))
    playlist.id.should(eq("PLFs4vir_WsTxontcYm5ctqp89cNBJKNrs"))
    playlist.thumbnail.should(eq("https://i.ytimg.com/vi/0FH9cgRhQ-k/hqdefault.jpg?sqp=-oaymwEXCOADEI4CSFryq4qpAwkIARUAAIhCGAE=&rs=AOn4CLD9depPKF_lMsYL7jWnLoCVyw-0pg"))
    playlist.title.should(eq("The Existential Crisis Playlist"))
    playlist.ucid.should(eq("UCsXVk37bltHxD1rDPwtNM8Q"))
    playlist.video_count.should(eq(34))
    playlist.videos.should(eq(Array(YouTubeStructs::PlaylistVideoRenderer).new))
  end
end

describe YouTubeStructs::Category do
  # TODO
end
