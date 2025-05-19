# This file automatically generates Crystal strings of rows within an HTML Javascript licenses table
#
# These strings will then be placed within a `<%= %>` statement in licenses.ecr at compile time which
# will be interpolated at run-time. This interpolation is only for the translation of the "source" string
# so maybe we can just switch to a non-translated string to simplify the logic here.
#
# The Javascript Web Labels table defined at https://www.gnu.org/software/librejs/free-your-javascript.html#step3
# for example just reiterates the name of the source file rather than use a "source" string.
all_javascript_files = Dir.glob("assets/**/*.js")

videojs_js = [] of String
invidious_js = [] of String

all_javascript_files.each do |js_path|
  if js_path.starts_with?("assets/videojs/")
    videojs_js << js_path[7..]
  else
    invidious_js << js_path[7..]
  end
end

def create_licence_tr(path, file_name, licence_name, licence_link, source_location)
  tr = <<-HTML
    "<tr>
    <td><a href=\\"/#{path}\\">#{file_name}</a></td>
    <td><a href=\\"#{licence_link}\\">#{licence_name}</a></td>
    <td><a href=\\"#{source_location}\\">\#{translate(locale, "source")}</a></td>
    </tr>"
    HTML

  # New lines are removed as to allow for using String.join and StringLiteral.split
  # to get a clean list of each table row.
  tr.gsub('\n', "")
end

# TODO Use videojs-dependencies.yml to generate license info for videojs javascript
jslicence_table_rows = [] of String

invidious_js.each do |path|
  file_name = path.split('/')[-1]

  # A couple non Invidious JS files are also shipped alongside Invidious due to various reasons
  next if {
            "sse.js", "silvermine-videojs-quality-selector.min.js", "videojs-youtube-annotations.min.js",
          }.includes?(file_name)

  jslicence_table_rows << create_licence_tr(
    path: path,
    file_name: file_name,
    licence_name: "AGPL-3.0",
    licence_link: "https://www.gnu.org/licenses/agpl-3.0.html",
    source_location: path
  )
end

puts jslicence_table_rows.join("\n")
