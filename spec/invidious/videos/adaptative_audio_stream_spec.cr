require "../../parsers_helper.cr"

Spectator.describe Invidious::Videos do
  subject(streams) {
    described_class.parse_adaptative_formats(load_mock(mock_name))
  }

  describe ".parse_adaptative_formats" do
    provided mock_name: "streams/audio_stereo" do
      expect(streams.size).to eq(2)

      sample_one = streams[0]
      sample_two = streams[1]

      #
      # Test 1 / itag 139
      #

      expect(sample_one).to be_a(Invidious::Videos::AdaptativeAudioStream)
      sample_one = sample_one.as(Invidious::Videos::AdaptativeAudioStream)

      expect(sample_one.itag).to eq(139)
      expect(sample_one.label).to eq("low")
      expect(sample_one.url).to eq("https://rr5---sn-4g5edndl.googlevideo.com/videoplayback")

      expect(sample_one.last_modified).to eq(Time.utc(seconds: 1_677_975_303_i64, nanoseconds: 572_731_000))
      expect(sample_one.projection_type).to eq(Invidious::Videos::ProjType::Rectangular)

      expect(sample_one).to have_attributes(
        raw_mime_type: "audio/mp4; codecs=\"mp4a.40.5\"",
        mime_type: "audio/mp4",
        codecs: "mp4a.40.5",
        # Adaptative properties
        init_range: Invidious::Videos::ByteRange.new(0_u32, 640_u32),
        index_range: Invidious::Videos::ByteRange.new(641_u32, 2148_u32),
        # Common properties
        bitrate: 50_854,
        bitrate_avg: 48_788,
        content_length: 7_454_256,
        # Audio properties
        audio_quality: Invidious::Videos::AudioQuality::Low,
        audio_sample_rate: 22_050,
        audio_channels: 2,
        audio_loudness_db: -5.01,
        audio_spatial_type: Invidious::Videos::SpatialType::None
      )

      #
      # Test 2 / itag 251 (Note: most properties aren't checked)
      #

      expect(sample_two).to be_a(Invidious::Videos::AdaptativeAudioStream)
      sample_two = sample_two.as(Invidious::Videos::AdaptativeAudioStream)

      expect(sample_two.itag).to eq(251)
      expect(sample_two.label).to eq("medium")

      expect(sample_two).to have_attributes(
        raw_mime_type: "audio/webm; codecs=\"opus\"",
        mime_type: "audio/webm",
        codecs: "opus",
        # Audio properties
        audio_quality: Invidious::Videos::AudioQuality::Medium,
        audio_sample_rate: 48_000,
        audio_channels: 2,
        audio_loudness_db: -5.01,
        audio_spatial_type: Invidious::Videos::SpatialType::None
      )
    end

    provided mock_name: "streams/audio_spatial" do
      expect(streams.size).to eq(2)

      sample_one = streams[0] # Quad
      sample_two = streams[1] # 5.1

      # Test 1

      expect(sample_one).to be_a(Invidious::Videos::AdaptativeAudioStream)
      sample_one = sample_one.as(Invidious::Videos::AdaptativeAudioStream)

      expect(sample_one.itag).to eq(327)

      expect(sample_one).to have_attributes(
        audio_quality: Invidious::Videos::AudioQuality::Medium,
        audio_sample_rate: 44_100,
        audio_channels: 6,
        audio_loudness_db: 0.0,
        audio_spatial_type: Invidious::Videos::SpatialType::Ambisonics_5_1
      )

      # Test 2

      expect(sample_two).to be_a(Invidious::Videos::AdaptativeAudioStream)
      sample_two = sample_two.as(Invidious::Videos::AdaptativeAudioStream)

      expect(sample_two.itag).to eq(338)

      expect(sample_two).to have_attributes(
        audio_quality: Invidious::Videos::AudioQuality::Medium,
        audio_sample_rate: 48_000,
        audio_channels: 4,
        audio_loudness_db: 0.0,
        audio_spatial_type: Invidious::Videos::SpatialType::AmbisonicsQuad
      )
    end

    provided mock_name: "streams/audio_multi_lang" do
      expect(streams.size).to eq(8)

      sample_one = streams[1] # English
      sample_two = streams[4] # hindi

      # Test 1

      expect(sample_one).to be_a(Invidious::Videos::AdaptativeAudioTrackStream)
      sample_one = sample_one.as(Invidious::Videos::AdaptativeAudioTrackStream)

      expect(sample_one.itag).to eq(249)

      expect(sample_one).to have_attributes(
        track_id: "en.0",
        track_name: "English",
        iso_code: "en",
        default: true
      )

      # Test 2

      expect(sample_two).to be_a(Invidious::Videos::AdaptativeAudioTrackStream)
      sample_two = sample_two.as(Invidious::Videos::AdaptativeAudioTrackStream)

      expect(sample_two.itag).to eq(249)

      expect(sample_two).to have_attributes(
        track_id: "hi.0",
        track_name: "Hindi",
        iso_code: "hi",
        default: false
      )
    end
  end
end
