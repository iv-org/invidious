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

function download_video(title) {
  var children = document.getElementById("download_widget").children;
  var progress = document.getElementById("download-progress");
  var url = "";

  document.getElementById("progress-container").style.display = "";

  for (i = 0; i < children.length; i++) {
    if (children[i].selected) {
      url = children[i].getAttribute("data-url");
    }
  }

  url = "/videoplayback" + url.split("/videoplayback")[1];

  var xhr = new XMLHttpRequest();
  xhr.open("GET", url);
  xhr.responseType = "arraybuffer";
  
  xhr.onprogress = function(event) {
    if (event.lengthComputable) {
      progress.style.width = "" + (event.loaded / event.total)*100 + "%";
    }
  };

  xhr.onload = function(event) {
    if (event.currentTarget.status != 200) {
      console.log("Downloading " + title + " failed.")
      document.getElementById("progress-container").style.display = "none";
      progress.style.width = "0%";

      return;
    }

    var data = new Blob([xhr.response], {'type' : 'video/mp4'});
    var videoFile = window.URL.createObjectURL(data);

    var link = document.createElement('a');
    link.href = videoFile;
    link.setAttribute('download', title);
    document.body.appendChild(link);

    window.requestAnimationFrame(function() {
      var event = new MouseEvent('click');
      link.dispatchEvent(event);
      document.body.removeChild(link);
    });

    document.getElementById("progress-container").style.display = "none";
    progress.style.width = "0%";
  };

  xhr.send(null);
}