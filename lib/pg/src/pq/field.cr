module PQ
  class Field
    getter name, type_oid

    def initialize(@name : String, @col_oid : Int32, @table_oid : Int16,
                   @type_oid : Int32, @type_size : Int16, @type_modifier : Int32,
                   @format : Int16)
    end
  end
end
