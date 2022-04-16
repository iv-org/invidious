module Invidious::Frontend::SearchFilters
  extend self

  # Generate the search filters collapsable widget.
  def generate(filters : Search::Filters, query : String, page : Int, locale : String) : String
    return String.build(8000) do |str|
      str << "<div id='filters'>\n"
      str << "\t<details id='filters-collapse'>"
      str << "\t\t<summary>" << translate(locale, "search_filters_title") << "</summary>\n"

      str << "\t\t<div id='filters-box'><form action='/search' method='get'>\n"

      str << "\t\t\t<input type='hidden' name='q' value='" << HTML.escape(query) << "'>\n"
      str << "\t\t\t<input type='hidden' name='page' value='" << page << "'>\n"

      str << "\t\t\t<div id='filters-flex'>"

      filter_wrapper(date)
      filter_wrapper(type)
      filter_wrapper(duration)
      filter_wrapper(features)
      filter_wrapper(sort)

      str << "\t\t\t</div>\n"

      str << "\t\t\t<div id='filters-apply'>"
      str << "<button type='submit' class=\"pure-button pure-button-primary\">"
      str << translate(locale, "search_filters_apply_button")
      str << "</button></div>\n"

      str << "\t\t</form></div>\n"

      str << "\t</details>\n"
      str << "</div>\n"
    end
  end

  # Generate wrapper HTML (`<div>`, filter name, etc...) around the
  # `<input>` elements of a search filter
  macro filter_wrapper(name)
    str << "\t\t\t\t<div class=\"filter-column\"><fieldset>\n"

    str << "\t\t\t\t\t<legend><div class=\"filter-name underlined\">"
    str << translate(locale, "search_filters_{{name}}_label")
    str << "</div></legend>\n"

    str << "\t\t\t\t\t<div class=\"filter-options\">\n"
    make_{{name}}_filter_options(str, filters.{{name}}, locale)
    str << "\t\t\t\t\t</div>"

    str << "\t\t\t\t</fieldset></div>\n"
  end

  # Generates the HTML for the list of radio buttons of the "date" search filter
  def make_date_filter_options(str : String::Builder, value : Search::Filters::Date, locale : String)
    {% for value in Invidious::Search::Filters::Date.constants %}
      {% date = value.underscore %}

      str << "\t\t\t\t\t\t<div>"
      str << "<input type='radio' name='date' id='filter-date-{{date}}' value='{{date}}'"
      str << " checked" if value.{{date}}?
      str << '>'

      str << "<label for='filter-date-{{date}}'>"
      str << translate(locale, "search_filters_date_option_{{date}}")
      str << "</label></div>\n"
    {% end %}
  end

  # Generates the HTML for the list of radio buttons of the "type" search filter
  def make_type_filter_options(str : String::Builder, value : Search::Filters::Type, locale : String)
    {% for value in Invidious::Search::Filters::Type.constants %}
      {% type = value.underscore %}

      str << "\t\t\t\t\t\t<div>"
      str << "<input type='radio' name='type' id='filter-type-{{type}}' value='{{type}}'"
      str << " checked" if value.{{type}}?
      str << '>'

      str << "<label for='filter-type-{{type}}'>"
      str << translate(locale, "search_filters_type_option_{{type}}")
      str << "</label></div>\n"
    {% end %}
  end

  # Generates the HTML for the list of radio buttons of the "duration" search filter
  def make_duration_filter_options(str : String::Builder, value : Search::Filters::Duration, locale : String)
    {% for value in Invidious::Search::Filters::Duration.constants %}
      {% duration = value.underscore %}

      str << "\t\t\t\t\t\t<div>"
      str << "<input type='radio' name='duration' id='filter-duration-{{duration}}' value='{{duration}}'"
      str << " checked" if value.{{duration}}?
      str << '>'

      str << "<label for='filter-duration-{{duration}}'>"
      str << translate(locale, "search_filters_duration_option_{{duration}}")
      str << "</label></div>\n"
    {% end %}
  end

  # Generates the HTML for the list of checkboxes of the "features" search filter
  def make_features_filter_options(str : String::Builder, value : Search::Filters::Features, locale : String)
    {% for value in Invidious::Search::Filters::Features.constants %}
      {% if value.stringify != "All" && value.stringify != "None" %}
        {% feature = value.underscore %}

        str << "\t\t\t\t\t\t<div>"
        str << "<input type='checkbox' name='features' id='filter-feature-{{feature}}' value='{{feature}}'"
        str << " checked" if value.{{feature}}?
        str << '>'

        str << "<label for='filter-feature-{{feature}}'>"
        str << translate(locale, "search_filters_features_option_{{feature}}")
        str << "</label></div>\n"
      {% end %}
    {% end %}
  end

  # Generates the HTML for the list of radio buttons of the "sort" search filter
  def make_sort_filter_options(str : String::Builder, value : Search::Filters::Sort, locale : String)
    {% for value in Invidious::Search::Filters::Sort.constants %}
      {% sort = value.underscore %}

      str << "\t\t\t\t\t\t<div>"
      str << "<input type='radio' name='sort' id='filter-sort-{{sort}}' value='{{sort}}'"
      str << " checked" if value.{{sort}}?
      str << '>'

      str << "<label for='filter-sort-{{sort}}'>"
      str << translate(locale, "search_filters_sort_option_{{sort}}")
      str << "</label></div>\n"
    {% end %}
  end
end
