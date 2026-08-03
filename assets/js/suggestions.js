"use strict";
const searchbox = document.getElementById("searchbox");
const searchContainer = document.getElementById("search-container");
const suggestions = document.getElementById("suggestions");
let selectedSuggestion = -1;
let suggestionController;
let queuedSuggestions = 0;

function resetSuggestions() {
  suggestions.textContent = "";
  selectedSuggestion = -1;
}

searchbox?.addEventListener("input", function () {
  // If there is already a request in progress,
  // abort. The user has made another input,
  // invalidating the old query.
  if (suggestionController != undefined) {
    suggestionController.abort();
  }

  // Only make a request for suggestions after
  // there is a delay of at least 150 milliseconds
  // between inputs.
  queuedSuggestions++;
  setTimeout(async function () {
    queuedSuggestions--;
    if (queuedSuggestions != 0) {
      return;
    }

    // Only continue for queries of more than one
    // character.
    if (searchbox.value.length < 2) {
      resetSuggestions();
      return;
    }

    // Create the controller which will be
    // used to abort this request if another
    // is made before it finishes.
    suggestionController = new AbortController();
    const signal = suggestionController.signal;

    // Make the request for suggestions.
    try {
      const resp = await fetch(
        `/api/v1/search/suggestions?q=${encodeURIComponent(searchbox.value)}`,
        { signal },
      );
      const body = await resp.json();

      // Put the results into DOM.
      resetSuggestions();
      const results = body.suggestions;
      for (let i = 0; i < results.length; i++) {
        const s = document.createElement("a");
        s.href = "/search";
        s.innerText = results[i];
        s.setAttribute("role", "option");
        s.setAttribute("aria-selected", "false");
        s.addEventListener("click", function (e) {
          searchbox.value = results[i];
          if (searchbox.form?.requestSubmit) {
            searchbox.form.requestSubmit();
          } else {
            searchbox.form?.submit();
          }
          e.preventDefault();
        });
        suggestions.appendChild(s);
      }
    } catch (err) {
      // Discard AbortError as it is expected.
      if (err.name !== "AbortError") {
        console.error(err);
      }
    }
  }, 150);
});

searchbox?.addEventListener("keydown", function (e) {
  const currentSuggestions = suggestions.children;

  // Navigate suggestions by key.
  switch (e.key) {
    case "ArrowDown":
      selectedSuggestion++;
      e.preventDefault();
      break;
    case "ArrowUp":
      selectedSuggestion--;
      e.preventDefault();
      break;
    case "Enter":
      if (selectedSuggestion != -1) {
        currentSuggestions[selectedSuggestion].click();
        e.preventDefault();
        return;
      }
      break;
  }

  // Loop around if you go beyond the end
  // or before -1 (the resting position).
  if (selectedSuggestion >= currentSuggestions.length) {
    selectedSuggestion = -1;
  } else if (selectedSuggestion < -1) {
    selectedSuggestion = currentSuggestions.length - 1;
  }

  // Remove .active class from all elements
  // except the active one.
  for (let i = 0; i < currentSuggestions.length; i++) {
    if (i == selectedSuggestion) {
      currentSuggestions[i].classList.add("active");
      currentSuggestions[i].setAttribute("aria-selected", "true");
    } else if (currentSuggestions[i].classList.contains("active")) {
      currentSuggestions[i].classList.remove("active");
      currentSuggestions[i].setAttribute("aria-selected", "false");
    }
  }
});
