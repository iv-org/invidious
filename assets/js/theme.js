const themeSelector = document.querySelector("#theme-selector");
themeSelector.addEventListener("change", (event) => {
  const select = event.target;
  const selected = select.options[select.selectedIndex].text;
  applyTheme(selected);
});

const colorSchemeSelector = document.querySelector("#color-scheme");
colorSchemeSelector.addEventListener("change", (event) => {
  const select = event.target;
  const selected = select.options[select.selectedIndex].text;
  applyColorScheme(selected);
});

function applyTheme(theme) {
  const link = document.createElement("link");
  link.rel = "stylesheet";
  link.href = `/css/theme-${theme}.css`;
  link.id = "theme-css";

  const themeCss = document.querySelector("#theme-css");
  if (themeCss) {
    themeCss.parentNode.removeChild(themeCss);
  }

  const head = document.getElementsByTagName("head")[0];
  head.appendChild(link);
}

function applyColorScheme(colorScheme) {
  document.body.classList.remove("dark-theme");
  document.body.classList.remove("light-theme");

  if (colorScheme === "dark" || colorScheme === "light") {
    document.body.classList.add(`${colorScheme}-theme`);
  }
}

applyTheme(themeSelector.options[themeSelector.selectedIndex].text);
applyColorScheme("dark");

// <link rel="stylesheet" href="/css/theme-dracula.css" />
// <link rel="stylesheet" href="/css/theme-catppuccin-latte.css" />
// <link rel="stylesheet" href="/css/ionicons.min.css" />
