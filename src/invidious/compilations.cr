struct Compilation
  include DB::Serializable

  property title : String
  property id : String
  property author : String
  property ucid : String
  property length_seconds : Int32
  property published : Time
  property plid : String
  property index : Int64
  property live_now : Bool

end