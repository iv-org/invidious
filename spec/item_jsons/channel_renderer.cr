# The following are examples of InnerTube channelRenderers
#
# A channelRenderer renders a channel to click on within the YouTube and Invidious UI. It is **not**
# the channel page itself.
CHANNEL_RENDERER_EXAMPLES = [
  # Standard channel without missing information
  {"channelRenderer": {
    # Channel ID
    "channelId": "UCsXVk37bltHxD1rDPwtNM8Q",

    # Author name. Can only be simpleText.\
    "title": {
      "simpleText": "Kurzgesagt – In a Nutshell",
    },

    # Endpoint to arrive on after clicking on renderer
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

    # Array of thumbnails in increasing quality.
    "thumbnail": {
      "thumbnails": [
        {
          "url":    "//yt3.ggpht.com/ytc/AKedOLRvMf1ZTTCnC5Wc0EGOVPyrdyvfvs20vtdTUxz_vQ=s88-c-k-c0x00ffffff-no-rj-mo",
          "width":  88,
          "height": 88,
        },
        {
          "url":    "//yt3.ggpht.com/ytc/AKedOLRvMf1ZTTCnC5Wc0EGOVPyrdyvfvs20vtdTUxz_vQ=s176-c-k-c0x00ffffff-no-rj-mo",
          "width":  176,
          "height": 176,
        },
      ],
    },

    # Description snippet.
    "descriptionSnippet": {
      "runs": [
        {
          "text": "Videos explaining things with optimistic nihilism. We are a small team who want to make science look beautiful. Because it is ...",
        },
      ],
    },

    # (short) Author information.
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

    # Amount of (public?) videos published on the channel.
    "videoCountText": {
      "runs": [
        {
          "text": "144",
        },
        {
          "text": " videos",
        },
      ],
    },

    # Should the subscribe button be renderers as a Subscribed variant?
    # "subscriptionButton": {subscribed": false},

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

    # Amount of subscribers the channel has, in an abbreviated format.
    #
    # This isn't sent by InnerTube for channels that wishes to hide it.
    "subscriberCountText": {
      "accessibility": {
        "accessibilityData": {
          "label": "15.7 million subscribers",
        },
      },
      "simpleText": "15.7M subscribers",
    },

    # Subscribe button renderer. Useless for Invidious.
    # "subscribeButton": {....},

    # "TrackingParams": "",

    # (Long) Author information.
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
  }}.to_json,

  # See first channelRenderer for detailed explanation. Besides channel data, the only difference
  # between this channelRenderer and the previous one is the lack of an "subscriberCountText"
  # as it is hidden on this channel.
  {"channelRenderer": {
    "channelId": "UCNhX3WQEkraW3VHPyup8jkQ",
    "title":     {
      "simpleText": "Langfocus",
    },
    "navigationEndpoint": {
      "clickTrackingParams": "",
      "commandMetadata":     {
        "webCommandMetadata": {
          "url":         "/channel/UCNhX3WQEkraW3VHPyup8jkQ",
          "webPageType": "WEB_PAGE_TYPE_CHANNEL",
          "rootVe":      3611,
          "apiUrl":      "/youtubei/v1/browse",
        },
      },
      "browseEndpoint": {
        "browseId":         "UCNhX3WQEkraW3VHPyup8jkQ",
        "canonicalBaseUrl": "/channel/UCNhX3WQEkraW3VHPyup8jkQ",
      },
    },
    "thumbnail": {
      "thumbnails": [
        {
          "url":    "//yt3.ggpht.com/ytc/AKedOLRvsTYz7nlOWrGLc1GzlV96kXxY1Q9IE1KzqbXa3g=s88-c-k-c0x00ffffff-no-rj-mo",
          "width":  88,
          "height": 88,
        },
        {
          "url":    "//yt3.ggpht.com/ytc/AKedOLRvsTYz7nlOWrGLc1GzlV96kXxY1Q9IE1KzqbXa3g=s176-c-k-c0x00ffffff-no-rj-mo",
          "width":  176,
          "height": 176,
        },
      ],
    },
    "descriptionSnippet": {
      "runs": [
        {
          "text": "Sharing my passion for languages and reaching out into the wider world.",
        },
      ],
    },
    "shortBylineText": {
      "runs": [
        {
          "text":               "Langfocus",
          "navigationEndpoint": {
            "clickTrackingParams": "",
            "commandMetadata":     {
              "webCommandMetadata": {
                "url":         "/channel/UCNhX3WQEkraW3VHPyup8jkQ",
                "webPageType": "WEB_PAGE_TYPE_CHANNEL",
                "rootVe":      3611,
                "apiUrl":      "/youtubei/v1/browse",
              },
            },
            "browseEndpoint": {
              "browseId":         "UCNhX3WQEkraW3VHPyup8jkQ",
              "canonicalBaseUrl": "/channel/UCNhX3WQEkraW3VHPyup8jkQ",
            },
          },
        },
      ],
    },
    "videoCountText": {
      "runs": [
        {
          "text": "165",
        },
        {
          "text": " videos",
        },
      ],
    },
    # "subscriptionButton": {subscribed": false},
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
    # "subscribeButton": {...},
    # "TrackingParams": "",
    "longBylineText": {
      "runs": [
        {
          "text":               "Langfocus",
          "navigationEndpoint": {
            "clickTrackingParams": "",
            "commandMetadata":     {
              "webCommandMetadata": {
                "url":         "/channel/UCNhX3WQEkraW3VHPyup8jkQ",
                "webPageType": "WEB_PAGE_TYPE_CHANNEL",
                "rootVe":      3611,
                "apiUrl":      "/youtubei/v1/browse",
              },
            },
            "browseEndpoint": {
              "browseId":         "UCNhX3WQEkraW3VHPyup8jkQ",
              "canonicalBaseUrl": "/channel/UCNhX3WQEkraW3VHPyup8jkQ",
            },
          },
        },
      ],
    },
  }}.to_json,
]
