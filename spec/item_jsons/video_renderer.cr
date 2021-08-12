# The following are examples of InnerTube videoRenderers
#
#  A videoRenderer renders a video to click on within the YouTube and Invidious UI. It is **not**
# the watchable video itself.
VIDEO_RENDERER_EXAMPLES = [
  {"videoRenderer" => {
    # Video ID
    "videoId" => "E1KkQrFEl2I",
    # Array of thumbnails in increasing quality.
    "thumbnail" => {
      "thumbnails" => [
        {
          "url"    => "https://i.ytimg.com/vi/E1KkQrFEl2I/hq720.jpg?sqp=-oaymwEjCOgCEMoBSFryq4qpAxUIARUAAAAAGAElAADIQj0AgKJDeAE=&rs=AOn4CLAE7cGsAxbjoQIKa04sXkfF9nTlzw",
          "width"  => 360,
          "height" => 202,
        },
        {
          "url"    => "https://i.ytimg.com/vi/E1KkQrFEl2I/hq720.jpg?sqp=-oaymwEXCNAFEJQDSFryq4qpAwkIARUAAIhCGAE=&rs=AOn4CLBnetdf_Lj9C6XpUuIVDV0mn7B2ew",
          "width"  => 720,
          "height" => 404,
        },
      ],
    },
    # Title. Can also be simpleText
    "title" => {
      "runs" => [
        {
          "text" => "How Large Can a Bacteria get? Life & Size 3",
        },
      ],
      "accessibility" => {
        "accessibilityData" => {
          "label" => "How Large Can a Bacteria get? Life & Size 3 by Kurzgesagt – In a Nutshell 9 months ago 11 minutes, 5 seconds 7,324,534 views",
        },
      },
    },

    # (Long) Author information.
    "longBylineText" => {
      "runs" => [
        {
          "text"               => "Kurzgesagt – In a Nutshell",
          "navigationEndpoint" => {
            "clickTrackingParams" => "",
            "commandMetadata"     => {
              "webCommandMetadata" => {
                "url"         => "/user/Kurzgesagt",
                "webPageType" => "WEB_PAGE_TYPE_CHANNEL",
                "rootVe"      => 3611,
                "apiUrl"      => "/youtubei/v1/browse",
              },
            },
            "browseEndpoint" => {
              "browseId"         => "UCsXVk37bltHxD1rDPwtNM8Q",
              "canonicalBaseUrl" => "/user/Kurzgesagt",
            },
          },
        },
      ],
    },

    # Published date
    #
    # For live videos (and possibly recently premiered videos) there is no published information.
    # Instead, in its place is the amount of people currently watching.
    "publishedTimeText" => {
      "simpleText" => "9 months ago",
    },

    # Video Length (locale specific?)
    "lengthText" => {
      "accessibility" => {
        "accessibilityData" => {
          "label" => "11 minutes, 5 seconds",
        },
      },
      "simpleText" => "11:05",
    },

    # View count (locale specific?)
    #
    # Typically views are stored under a "simpleText" in the "viewCountText". However, for
    # livestreams and premiered it is stored under a "runs" array: [{"text" =>123}, {"text" => "watching"}]
    #
    # When view count is disabled the "viewCountText" is not present on InnerTube data.
    "viewCountText" => {
      "simpleText" => "7,324,534 views",
    },

    # Endpoint to arrive on after clicking on renderer
    "navigationEndpoint" => {
      "clickTrackingParams" => "",
      "commandMetadata"     => {
        "webCommandMetadata" => {
          "url"         => "/watch?v=E1KkQrFEl2I",
          "webPageType" => "WEB_PAGE_TYPE_WATCH",
          "rootVe"      => 3832,
        },
      },
      "watchEndpoint" => {
        "videoId"                            => "E1KkQrFEl2I",
        "params"                             => "qgMKa3Vyemdlc2FndLoDCgj0juTts8vxj1S6AwoI4Lz4wObkpqh0ugMLCLOGu73S_MCcuwG6AwoI6Nmyi6a2-8ZgugMKCImerNeaqIrWdroDHhIcUkRDTVVDc1hWazM3Ymx0SHhEMXJEUHd0Tk04UboDCgji8sL8s9_j8hu6AwoIroO-kuTyidxhugMLCJSWjb7iwfS03gG6AwsIrNvJxeruqv_0AboDCwiRr7iB0-b93uEBugMKCNTbv-uz04eIEroDCwii0dvbjej74ssBugMLCNbouPHd55iEjAG6AwoIpvvOyc3pwtVCugMLCJbux5v_3NKIrgG6AwsIrJPl67y13v6QAboDCwipjcSCw9Xl6qgB8gMFDSaq1Tw%3D",
        "watchEndpointSupportedOnesieConfig" => {
          "html5PlaybackOnesieConfig" => {
            "commonConfig" => {
              "url" => "https://r1---sn-nx57ynlk.googlevideo.com/initplayback?source=youtube&orc=1&oeis=1&c=WEB&oad=3200&ovd=3200&oaad=11000&oavd=11000&ocs=700&oewis=1&oputc=1&ofpcc=1&msp=1&odeak=1&odepv=1&osfc=1&ip=198.54.131.169&id=1352a442b1449762&initcwndbps=2022500&mt=1628653969&oweuc=&pxtags=Cg4KAnR4EggyNDAyNzcwNg&rxtags=Cg4KAnR4EggyNDAyNzcwMw%2CCg4KAnR4EggyNDAyNzcwNA%2CCg4KAnR4EggyNDAyNzcwNQ%2CCg4KAnR4EggyNDAyNzcwNg",
            },
          },
        },
      },
    },

    # Video badges. IE Live, CC, etc
    "badges" => [
      {
        "metadataBadgeRenderer" => {
          "style"             => "BADGE_STYLE_TYPE_SIMPLE",
          "label"             => "CC",
          "trackingParams"    => "",
          "accessibilityData" => {
            "label" => "Closed captions",
          },
        },
      },
    ],

    # Author badges
    "ownerBadges" => [
      {
        "metadataBadgeRenderer" => {
          "icon" => {
            "iconType" => "CHECK_CIRCLE_THICK",
          },
          "style"             => "BADGE_STYLE_TYPE_VERIFIED",
          "tooltip"           => "Verified",
          "trackingParams"    => "",
          "accessibilityData" => {
            "label" => "Verified",
          },
        },
      },
    ],

    # Author name
    "ownerText" => {
      "runs" => [
        {
          "text"               => "Kurzgesagt – In a Nutshell",
          "navigationEndpoint" => {
            "clickTrackingParams" => "",
            "commandMetadata"     => {
              "webCommandMetadata" => {
                "url"         => "/user/Kurzgesagt",
                "webPageType" => "WEB_PAGE_TYPE_CHANNEL",
                "rootVe"      => 3611,
                "apiUrl"      => "/youtubei/v1/browse",
              },
            },
            "browseEndpoint" => {
              "browseId"         => "UCsXVk37bltHxD1rDPwtNM8Q",
              "canonicalBaseUrl" => "/user/Kurzgesagt",
            },
          },
        },
      ],
    },

    # (Long) Author information.
    # TODO find difference between short and long BylineText
    "shortBylineText" => {
      "runs" => [
        {
          "text"               => "Kurzgesagt – In a Nutshell",
          "navigationEndpoint" => {
            "clickTrackingParams" => "",
            "commandMetadata"     => {
              "webCommandMetadata" => {
                "url"         => "/user/Kurzgesagt",
                "webPageType" => "WEB_PAGE_TYPE_CHANNEL",
                "rootVe"      => 3611,
                "apiUrl"      => "/youtubei/v1/browse",
              },
            },
            "browseEndpoint" => {
              "browseId"         => "UCsXVk37bltHxD1rDPwtNM8Q",
              "canonicalBaseUrl" => "/user/Kurzgesagt",
            },
          },
        },
      ],
    },
    # "trackingParams" => "",
    # "showActionMenu" => false,
    "shortViewCountText" => {
      "accessibility" => {
        "accessibilityData" => {
          "label" => "7.3 million views",
        },
      },
      "simpleText" => "7.3M views",
    },
    # "menu" : {...} | renderer for 3 dot menu

    # Channel pfp renderer. Also unused on Invidious
    "channelThumbnailSupportedRenderers" => {
      "channelThumbnailWithLinkRenderer" => {
        "thumbnail" => {
          "thumbnails" => [
            {
              "url"    => "https://yt3.ggpht.com/ytc/AKedOLRvMf1ZTTCnC5Wc0EGOVPyrdyvfvs20vtdTUxz_vQ=s68-c-k-c0x00ffffff-no-rj",
              "width"  => 68,
              "height" => 68,
            },
          ],
        },
        "navigationEndpoint" => {
          "clickTrackingParams" => "",
          "commandMetadata"     => {
            "webCommandMetadata" => {
              "url"         => "/user/Kurzgesagt",
              "webPageType" => "WEB_PAGE_TYPE_CHANNEL",
              "rootVe"      => 3611,
              "apiUrl"      => "/youtubei/v1/browse",
            },
          },
          "browseEndpoint" => {
            "browseId"         => "UCsXVk37bltHxD1rDPwtNM8Q",
            "canonicalBaseUrl" => "/user/Kurzgesagt",
          },
        },
        "accessibility" => {
          "accessibilityData" => {
            "label" => "Go to channel",
          },
        },
      },
    },

    # Provides the overlays on the thumbnails. This is currently
    # used as an fallback for the "lengthText" attribute when that
    # doesn't exist.
    "thumbnailOverlays" => [
      {
        "thumbnailOverlayTimeStatusRenderer" => {
          "text" => {
            "accessibility" => {
              "accessibilityData" => {
                "label" => "11 minutes, 5 seconds",
              },
            },
            "simpleText" => "11:05",
          },
          "style" => "DEFAULT",
        },
      },
      # Renderer for watch later, add to playlist, etc overlay buttons on YouTube.
      # Each separate btn has a different renderer
      # {"thumbnailOverlayToggleButtonRenderer" => {...}}

      # thumbnailOverlayNowPlayingRenderer: {...} | Renders "Now playing"
    ],

    # Description snippet
    "detailedMetadataSnippets" => [
      {
        "snippetText" => {
          "runs" => [
            {
              "text" => "In and out, in and out. Staying alive is about doing things. This very second, your cells are combusting glucose molecules with ...",
            },
          ],
        },
        "snippetHoverText" => {
          "runs" => [
            {
              "text" => "From the video description",
            },
          ],
        },
        "maxOneLine" => false,
      },
    ],
  }}.to_json,
]
