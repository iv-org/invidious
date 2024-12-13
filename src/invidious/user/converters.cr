def convert_theme(theme)
  case theme
  when "true"
    "dark"
  when "false"
    "light"
  when "", nil
    nil
  else
    theme
  end
end
