/*! (C) 2014 - 2015 Shinnosuke Watanabe - Mit Style License */
(function() {
  'use strict';
  var loc, value;

  loc = window.location;

  if (loc.origin) {
    return;
  }

  value = loc.protocol + '//' + loc.hostname + (loc.port ? ':' + loc.port : '');

  try {
    Object.defineProperty(loc, 'origin', {
      value: value,
      enumerable: true
    });
  } catch (_error) {
    loc.origin = value;
  }

}).call(this);
