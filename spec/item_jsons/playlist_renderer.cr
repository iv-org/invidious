# The following are examples of InnerTube playlistRenderers
#
# A playlistRenderer renders a playlist to click on within the YouTube and Invidious UI. It is **not** the playlist itself.
PLAYLIST_RENDERER_EXAMPLES = [
  {"playlistRenderer": {
    "playlistId": "PLFs4vir_WsTwEd-nJgVJCZPNL3HALHHpF",
    "title":      {
      "simpleText": "The Universe and Space stuff",
    },

    # Array of thumbnails in increasing quality, taken from the last few videos within the playlist.
    "thumbnails": [
      {
        "thumbnails": [
          {
            "url":    "https://i.ytimg.com/vi/0FH9cgRhQ-k/hqdefault.jpg?sqp=-oaymwEWCKgBEF5IWvKriqkDCQgBFQAAiEIYAQ==&rs=AOn4CLD9giG-6BICfsfD6p8l0OxjPEqiPg",
            "width":  168,
            "height": 94,
          },
          {
            "url":    "https://i.ytimg.com/vi/0FH9cgRhQ-k/hqdefault.jpg?sqp=-oaymwEWCMQBEG5IWvKriqkDCQgBFQAAiEIYAQ==&rs=AOn4CLBJlY_7z-Jfm-lPgZvzcLsuotYD2g",
            "width":  196,
            "height": 110,
          },
          {
            "url":    "https://i.ytimg.com/vi/0FH9cgRhQ-k/hqdefault.jpg?sqp=-oaymwEXCPYBEIoBSFryq4qpAwkIARUAAIhCGAE=&rs=AOn4CLCollsqaYxSm_va6vSN6oK8mnSFhw",
            "width":  246,
            "height": 138,
          },
          {
            "url":    "https://i.ytimg.com/vi/0FH9cgRhQ-k/hqdefault.jpg?sqp=-oaymwEXCNACELwBSFryq4qpAwkIARUAAIhCGAE=&rs=AOn4CLDOCmzlwvvYsaaFO2u8lyWPrZULkw",
            "width":  336,
            "height": 188,
          },
        ],
      },
      {
        "thumbnails": [
          {
            "url":    "https://i.ytimg.com/vi/G-WO-z-QuWI/default.jpg",
            "width":  43,
            "height": 20,
          },
        ],
      },
      {
        "thumbnails": [
          {
            "url":    "https://i.ytimg.com/vi/qEfPBt9dU60/default.jpg",
            "width":  43,
            "height": 20,
          },
        ],
      },
      {
        "thumbnails": [
          {
            "url":    "https://i.ytimg.com/vi/gLZJlf5rHVs/default.jpg",
            "width":  43,
            "height": 20,
          },
        ],
      },
      {
        "thumbnails": [
          {
            "url":    "https://i.ytimg.com/vi/3mnSDifDSxQ/default.jpg",
            "width":  43,
            "height": 20,
          },
        ],
      },
    ],

    # Amount of videos in playlist
    "videoCount": "32",

    # Endpoint to arrive on after clicking on renderer
    "navigationEndpoint": {
      "clickTrackingParams": "",
      "commandMetadata":     {
        "webCommandMetadata": {
          "url":         "/watch?v=0FH9cgRhQ-k&list=PLFs4vir_WsTwEd-nJgVJCZPNL3HALHHpF",
          "webPageType": "WEB_PAGE_TYPE_WATCH",
          "rootVe":      3832,
        },
      },
      "watchEndpoint": {
        "videoId":    "0FH9cgRhQ-k",
        "playlistId": "PLFs4vir_WsTwEd-nJgVJCZPNL3HALHHpF",
        "params":     "OAI%3D",
        # "loggingContext": {...},
        # "watchEndpointSupportedOnesieConfig": {...}
      },
    },

    # Renderer for the view full playlist link. This is stored in a
    # runs object inside
    # "viewPlaylistText": {...},

    # (short) Author information
    "shortBylineText": {
      "runs": [
        {
          "text":               "Kurzgesagt – In a Nutshell",
          "navigationEndpoint": {
            "clickTrackingParams": "",
            "commandMetadata":     {
              "webCommandMetadata": {
                "url":         "/user/Kurzgesagt",
                "webPageType": "WEB_PAGE_TYPE_CHANNEL",
                "rootVe":      3611,
                "apiUrl":      "/youtubei/v1/browse",
              },
            },
            "browseEndpoint": {
              "browseId":         "UCsXVk37bltHxD1rDPwtNM8Q",
              "canonicalBaseUrl": "/user/Kurzgesagt",
            },
          },
        },
      ],
    },

    # Updated/Published date
    "publishedTimeText": {
      "simpleText": "Updated 7 days ago",
    },

    # Two or less videos from the playlist. This is used to render preview (text-only)
    # next to the playlist on search results. Each content below is a mini videoRenderer
    "videos": [
      {
        "childVideoRenderer": {
          "title": {
            "simpleText": "The Largest Black Hole in the Universe - Size Comparison",
          },
          "navigationEndpoint": {
            "clickTrackingParams": "",
            "commandMetadata":     {
              "webCommandMetadata": {
                "url":         "/watch?v=0FH9cgRhQ-k&list=PLFs4vir_WsTwEd-nJgVJCZPNL3HALHHpF",
                "webPageType": "WEB_PAGE_TYPE_WATCH",
                "rootVe":      3832,
              },
            },
            "watchEndpoint": {
              "videoId":    "0FH9cgRhQ-k",
              "playlistId": "PLFs4vir_WsTwEd-nJgVJCZPNL3HALHHpF",
              # "loggingContext": {...},
              # "watchEndpointSupportedOnesieConfig": {...}
            },
          },
          "lengthText": {
            "accessibility": {
              "accessibilityData": {
                "label": "13 minutes, 44 seconds",
              },
            },
            "simpleText": "13:44",
          },
          "videoId": "0FH9cgRhQ-k",
        },
      },
      {
        "childVideoRenderer": {
          "title": {
            "simpleText": "How To Terraform Venus (Quickly)",
          },
          "navigationEndpoint": {
            "clickTrackingParams": "",
            "commandMetadata":     {
              "webCommandMetadata": {
                "url":         "/watch?v=G-WO-z-QuWI&list=PLFs4vir_WsTwEd-nJgVJCZPNL3HALHHpF",
                "webPageType": "WEB_PAGE_TYPE_WATCH",
                "rootVe":      3832,
              },
            },
            "watchEndpoint": {
              "videoId":    "G-WO-z-QuWI",
              "playlistId": "PLFs4vir_WsTwEd-nJgVJCZPNL3HALHHpF",
              # "loggingContext": {...},
              # "watchEndpointSupportedOnesieConfig": {...}
            },
          },
          "lengthText": {
            "accessibility": {
              "accessibilityData": {
                "label": "12 minutes, 48 seconds",
              },
            },
            "simpleText": "12:48",
          },
          "videoId": "G-WO-z-QuWI",
        },
      },
    ],

    # Amount of videos in playlist
    "videoCountText": {
      "runs": [
        {
          "text": "32",
        },
        {
          "text": " videos",
        },
      ],
    },
    # "TrackingParams": "",

    # Overlay counting amount of videos in playlist
    # "thumbnailText": {...},

    # (Long) Author information
    "longBylineText": {
      "runs": [
        {
          "text":               "Kurzgesagt – In a Nutshell",
          "navigationEndpoint": {
            "clickTrackingParams": "",
            "commandMetadata":     {
              "webCommandMetadata": {
                "url":         "/user/Kurzgesagt",
                "webPageType": "WEB_PAGE_TYPE_CHANNEL",
                "rootVe":      3611,
                "apiUrl":      "/youtubei/v1/browse",
              },
            },
            "browseEndpoint": {
              "browseId":         "UCsXVk37bltHxD1rDPwtNM8Q",
              "canonicalBaseUrl": "/user/Kurzgesagt",
            },
          },
        },
      ],
    },

    # Owner badges
    "ownerBadges": [
      {
        "metadataBadgeRenderer": {
          "icon": {
            "iconType": "CHECK_CIRCLE_THICK",
          },
          "style":             "BADGE_STYLE_TYPE_VERIFIED",
          "tooltip":           "Verified",
          "TrackingParams":    "",
          "accessibilityData": {
            "label": "Verified",
          },
        },
      },
    ],

    # The actual thumbnail of the playlist
    #
    # YouTube allows for defining custom ones instead of just using the last video
    # in the playlist. As such, that can be accessed from here.
    "thumbnailRenderer": {
      "playlistVideoThumbnailRenderer": {
        "thumbnail": {
          "thumbnails": [
            {
              "url":    "https://i.ytimg.com/vi/0FH9cgRhQ-k/hqdefault.jpg?sqp=-oaymwEWCKgBEF5IWvKriqkDCQgBFQAAiEIYAQ==&rs=AOn4CLD9giG-6BICfsfD6p8l0OxjPEqiPg",
              "width":  168,
              "height": 94,
            },
            {
              "url":    "https://i.ytimg.com/vi/0FH9cgRhQ-k/hqdefault.jpg?sqp=-oaymwEWCMQBEG5IWvKriqkDCQgBFQAAiEIYAQ==&rs=AOn4CLBJlY_7z-Jfm-lPgZvzcLsuotYD2g",
              "width":  196,
              "height": 110,
            },
            {
              "url":    "https://i.ytimg.com/vi/0FH9cgRhQ-k/hqdefault.jpg?sqp=-oaymwEXCPYBEIoBSFryq4qpAwkIARUAAIhCGAE=&rs=AOn4CLCollsqaYxSm_va6vSN6oK8mnSFhw",
              "width":  246,
              "height": 138,
            },
            {
              "url":    "https://i.ytimg.com/vi/0FH9cgRhQ-k/hqdefault.jpg?sqp=-oaymwEXCNACELwBSFryq4qpAwkIARUAAIhCGAE=&rs=AOn4CLDOCmzlwvvYsaaFO2u8lyWPrZULkw",
              "width":  336,
              "height": 188,
            },
          ],
        },
      },
    },

    # Thumbnail overlays such as the play all button or the video count.
    # "thumbnailOverlays": []
  }}.to_json,

  # Playlists rendered on a grid has a slightly different format
  #
  # IE lack of author information
  {"gridPlaylistRenderer": {
    "playlistId": "PLFs4vir_WsTxontcYm5ctqp89cNBJKNrs",

    # Playlist thumbnail in ascending quality
    "thumbnail": {
      "thumbnails": [
        {
          "url":    "https://i.ytimg.com/vi/0FH9cgRhQ-k/hqdefault.jpg?sqp=-oaymwEXCOADEI4CSFryq4qpAwkIARUAAIhCGAE=&rs=AOn4CLD9depPKF_lMsYL7jWnLoCVyw-0pg",
          "width":  480,
          "height": 270,
        },
      ],
    },

    # Playlist title and endpoint it redirects to on click
    "title": {
      "runs": [
        {
          "text":               "The Existential Crisis Playlist",
          "navigationEndpoint": {
            "clickTrackingParams": "",
            "commandMetadata":     {
              "webCommandMetadata": {
                "url":         "/watch?v=0FH9cgRhQ-k&list=PLFs4vir_WsTxontcYm5ctqp89cNBJKNrs",
                "webPageType": "WEB_PAGE_TYPE_WATCH",
                "rootVe":      3832,
              },
            },
            "watchEndpoint": {
              "videoId":    "0FH9cgRhQ-k",
              "playlistId": "PLFs4vir_WsTxontcYm5ctqp89cNBJKNrs",
              "params":     "OAI%3D",
              # "loggingContext": {...},
              # "watchEndpointSupportedOnesieConfig": {...}
            },
          },
        },
      ],
    },

    # Video count text in format
    "videoCountText": {
      "runs": [
        {
          "text": "34",
        },
        {
          "text": " videos",
        },
      ],
    },

    # Endpoint to arrive on after clicking on renderer
    "navigationEndpoint": {
      "clickTrackingParams": "",
      "commandMetadata":     {
        "webCommandMetadata": {
          "url":         "/watch?v=0FH9cgRhQ-k&list=PLFs4vir_WsTxontcYm5ctqp89cNBJKNrs",
          "webPageType": "WEB_PAGE_TYPE_WATCH",
          "rootVe":      3832,
        },
      },
      "watchEndpoint": {
        "videoId":    "0FH9cgRhQ-k",
        "playlistId": "PLFs4vir_WsTxontcYm5ctqp89cNBJKNrs",
        "params":     "OAI%3D",
        # "loggingContext": {...},
        # "watchEndpointSupportedOnesieConfig": {...}
      },
    },

    # Shortened video count text.
    "videoCountShortText": {
      "simpleText": "34",
    },
    # "TrackingParams": "",

    # Array of thumbnails in increasing quality, taken from the last few videos within the playlist.
    "sidebarThumbnails": [
      {
        "thumbnails": [
          {
            "url":    "https://i.ytimg.com/vi/JXeJANDKwDc/default.jpg",
            "width":  43,
            "height": 20,
          },
        ],
      },
      {
        "thumbnails": [
          {
            "url":    "https://i.ytimg.com/vi/Jzfpyo-q-RM/default.jpg",
            "width":  43,
            "height": 20,
          },
        ],
      },
      {
        "thumbnails": [
          {
            "url":    "https://i.ytimg.com/vi/qEfPBt9dU60/default.jpg",
            "width":  43,
            "height": 20,
          },
        ],
      },
    ],

    # Renderer for playlist size overlay on thumbnail
    "thumbnailText": {
      "runs": [
        {
          "text": "34",
          "bold": true,
        },
        {
          "text": " videos",
        },
      ],
    },

    # Amount of badges the channel has. IE verified.
    "ownerBadges": [
      {
        "metadataBadgeRenderer": {
          "icon": {
            "iconType": "CHECK_CIRCLE_THICK",
          },
          "style":             "BADGE_STYLE_TYPE_VERIFIED",
          "tooltip":           "Verified",
          "TrackingParams":    "",
          "accessibilityData": {
            "label": "Verified",
          },
        },
      },
    ],

    # Playlist thumbnail in ascending quality
    #
    # TODO find difference between this and "thumbnail" object.
    "thumbnailRenderer": {
      "playlistVideoThumbnailRenderer": {
        "thumbnail": {
          "thumbnails": [
            {
              "url":    "https://i.ytimg.com/vi/0FH9cgRhQ-k/hqdefault.jpg?sqp=-oaymwEXCOADEI4CSFryq4qpAwkIARUAAIhCGAE=&rs=AOn4CLD9depPKF_lMsYL7jWnLoCVyw-0pg",
              "width":  480,
              "height": 270,
            },
          ],
        },
      },
    },

    # Thumbnail overlays such as the play all button or the video count.
    # "thumbnailOverlays": [...],

    # Renderer for the view full playlist link. This is stored in a
    # runs object inside
    # "viewPlaylistText": {...}
  }}.to_json,
]
