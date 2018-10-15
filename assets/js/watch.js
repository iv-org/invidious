function toggle_parent(target) {
  body = target.parentNode.parentNode.children[1];
  if (body.style.display === null || body.style.display === "") {
    target.innerHTML = "[ + ]";
    body.style.display = "none";
  } else {
    target.innerHTML = "[ - ]";
    body.style.display = "";
  }
}

function toggle_comments(target) {
  body = target.parentNode.parentNode.parentNode.children[1];
  if (body.style.display === null || body.style.display === "") {
    target.innerHTML = "[ + ]";
    body.style.display = "none";
  } else {
    target.innerHTML = "[ - ]";
    body.style.display = "";
  }
}

function swap_comments(source) {
  if (source == "youtube") {
    get_youtube_comments();
  } else if (source == "reddit") {
    get_reddit_comments();
  }
}

function commaSeparateNumber(val) {
  while (/(\d+)(\d{3})/.test(val.toString())) {
    val = val.toString().replace(/(\d+)(\d{3})/, "$1" + "," + "$2");
  }
  return val;
}

String.prototype.supplant = function(o) {
  return this.replace(/{([^{}]*)}/g, function(a, b) {
    var r = o[b];
    return typeof r === "string" || typeof r === "number" ? r : a;
  });
};

function show_youtube_replies(target) {
  body = target.parentNode.parentNode.children[1];
  body.style.display = "";

  target.innerHTML = "Hide replies";
  target.setAttribute("onclick", "hide_youtube_replies(this)");
}

function hide_youtube_replies(target) {
  body = target.parentNode.parentNode.children[1];
  body.style.display = "none";

  target.innerHTML = "Show replies";
  target.setAttribute("onclick", "show_youtube_replies(this)");
}
