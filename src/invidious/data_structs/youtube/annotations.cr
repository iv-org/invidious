module YouTubeStructs
  struct Annotation
    include DB::Serializable

    property id : String
    # JSON String containing annotation data
    property annotations : String
  end
end
