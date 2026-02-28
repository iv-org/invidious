module Invidious::Routes
  private REQUEST_HEADERS_WHITELIST = {
    "accept",
    "accept-encoding",
    "cache-control",
    "content-length",
    "if-none-match",
    "range",
  }
  private RESPONSE_HEADERS_BLACKLIST = {
    "access-control-allow-origin",
    "alt-svc",
    "server",
    "cross-origin-opener-policy-report-only",
    "report-to",
    "cross-origin",
    "timing-allow-origin",
    "cross-origin-resource-policy",
  }
end
