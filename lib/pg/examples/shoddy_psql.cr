#!/usr/bin/env crystal
require "readline"
require "../src/pg"

url = ARGV[0]? || "postgres:///"
db = DB.open(url)

loop do
  query = Readline.readline("# ", true) || ""
  has_results = false
  begin
    db.query(query) do |rs|
      has_results = rs.column_count > 0
      if has_results
        # Gather rows, including a first row for the column names
        rows = [] of Array(typeof(rs.read))

        # The first row: column names
        rows << rs.column_count.times.map { |i| rs.column_name(i).as(typeof(rs.read)) }.to_a

        # The result rows
        rs.each do
          rows << rs.column_count.times.map { rs.read }.to_a
        end

        # Compute maximum sizes for each column for a nicer output
        sizes = [] of Int32
        rs.column_count.times do |i|
          # Add 2 for padding
          sizes << rows.max_of(&.[i].to_s.size.+(2))
        end

        # Print rows
        rows.each_with_index do |row, row_index|
          row.each_with_index do |value, col_index|
            print " |" if col_index > 0
            print " "
            col_size = sizes[col_index] - 2
            case value
            when Int, Float, PG::Numeric
              print value.to_s.rjust(col_size)
            else
              print value.to_s.ljust(col_size)
            end
          end

          # Write the separator ("---+---+---") after the first row
          if row_index == 0
            puts
            row.each_index do |col_index|
              print "+" if col_index > 0
              print "-" * sizes[col_index]
            end
          end

          puts
        end

        # Print numbers of rows
        count = rows.size - 1
        if count == 1
          puts "(1 row)"
        else
          puts "(#{count} rows)"
        end
      end
    end
  rescue e
    puts "ERROR: #{e.message}"
  end
  puts if has_results
end
