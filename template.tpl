___TERMS_OF_SERVICE___

By creating or modifying this file you agree to Google Tag Manager's Community
Template Gallery Developer Terms of Service available at
https://developers.google.com/tag-manager/gallery-tos (or such other URL as
Google may provide), as modified from time to time.


___INFO___

{
  "type": "MACRO",
  "id": "cvt_temp_public_id",
  "version": 1,
  "securityGroups": [],
  "displayName": "TrackAPI - Event ID",
  "description": "Returns the event_id from the dataLayer push (SPA/Next.js) or generates one with 8s cache (traditional sites). Use in the Facebook Pixel tag Event ID field to ensure deduplication between browser Pixel and TrackAPI CAPI.",
  "categories": [
    "UTILITY",
    "ANALYTICS"
  ],
  "containerContexts": [
    "WEB"
  ]
}


___TEMPLATE_PARAMETERS___

[
  {
    "type": "TEXT",
    "name": "ttl",
    "displayName": "Cache TTL (ms)",
    "simpleValueType": true,
    "defaultValue": "8000",
    "help": "Time in milliseconds to reuse the same event_id for the same event+route. Default: 8000 (8s). Required for SPAs (React, Next.js, Vue) that may fire the same event twice in a single render cycle.",
    "valueValidators": [
      {
        "type": "POSITIVE_NUMBER"
      }
    ]
  }
]


___SANDBOXED_JS_FOR_WEB_TEMPLATE___

var copyFromWindow = require('copyFromWindow');
var setInWindow = require('setInWindow');
var copyFromDataLayer = require('copyFromDataLayer');
var getTimestampMillis = require('getTimestampMillis');
var generateRandom = require('generateRandom');
var makeString = require('makeString');
var makeNumber = require('makeNumber');
var getUrl = require('getUrl');
var ObjectApi = require('Object');

// Priority 1: read event_id from the dataLayer push.
// In SPAs (Next.js, React), the PageViewTracker or trackEvent() puts the
// event_id in the push — both the FB Pixel browser tag and the TrackAPI SDK
// CAPI must use the SAME id for Meta deduplication. Without this check, the
// template generates its own id (different from the push) and Meta sees two
// events with distinct ids → counts both.
var dlEventId = copyFromDataLayer('event_id');
if (dlEventId) {
  return makeString(dlEventId);
}

// Priority 2: generate a new id with per-event+route cache.
// For traditional sites (WordPress, static pages) where autoPageView: true
// handles PageViews and no event_id is present in the push.
var ttl = makeNumber(data.ttl) || 8000;

var cache = copyFromWindow('_tapiEventIdCache');
if (!cache) {
  cache = {};
  setInWindow('_tapiEventIdCache', cache, true);
}

var eventName = makeString(data.event || 'unknown');
var path = makeString(getUrl('path') || '');
var qs = makeString(getUrl('query') || '');

var key = eventName + '|' + path + '|' + qs;
var now = getTimestampMillis();

var keys = ObjectApi.keys(cache);
var clean = {};
for (var i = 0; i < keys.length; i++) {
  var k = keys[i];
  if (now - cache[k].time <= ttl) {
    clean[k] = cache[k];
  }
}
cache = clean;
setInWindow('_tapiEventIdCache', cache, true);

if (cache[key] && (now - cache[key].time < ttl)) {
  return cache[key].id;
}

var rand = makeString(generateRandom(0, 2147483647));
var newId = 'evt_' + makeString(now) + '_' + rand;
cache[key] = { id: newId, time: now };

return newId;


___WEB_PERMISSIONS___

[
  {
    "instance": {
      "key": {
        "publicId": "read_data_layer",
        "versionId": "1"
      },
      "param": [
        {
          "key": "allowedKeys",
          "value": {
            "type": 2,
            "listItem": [
              {
                "type": 3,
                "mapKey": [
                  {
                    "type": 1,
                    "string": "key"
                  }
                ],
                "mapValue": [
                  {
                    "type": 1,
                    "string": "event_id"
                  }
                ]
              }
            ]
          }
        }
      ]
    },
    "clientAnnotations": {
      "isEditedByUser": true
    },
    "isRequired": true
  },
  {
    "instance": {
      "key": {
        "publicId": "access_globals",
        "versionId": "1"
      },
      "param": [
        {
          "key": "keys",
          "value": {
            "type": 2,
            "listItem": [
              {
                "type": 3,
                "mapKey": [
                  {
                    "type": 1,
                    "string": "key"
                  },
                  {
                    "type": 1,
                    "string": "read"
                  },
                  {
                    "type": 1,
                    "string": "write"
                  },
                  {
                    "type": 1,
                    "string": "execute"
                  }
                ],
                "mapValue": [
                  {
                    "type": 1,
                    "string": "_tapiEventIdCache"
                  },
                  {
                    "type": 8,
                    "boolean": true
                  },
                  {
                    "type": 8,
                    "boolean": true
                  },
                  {
                    "type": 8,
                    "boolean": false
                  }
                ]
              }
            ]
          }
        }
      ]
    },
    "clientAnnotations": {
      "isEditedByUser": true
    },
    "isRequired": true
  },
  {
    "instance": {
      "key": {
        "publicId": "get_url",
        "versionId": "1"
      },
      "param": [
        {
          "key": "urlParts",
          "value": {
            "type": 1,
            "string": "any"
          }
        },
        {
          "key": "queriesAllowed",
          "value": {
            "type": 1,
            "string": "any"
          }
        }
      ]
    },
    "clientAnnotations": {
      "isEditedByUser": true
    },
    "isRequired": true
  }
]


___TESTS___

scenarios:
  - name: 'returns event_id from dataLayer when present'
    code: |-
      mock('copyFromDataLayer', function(key) {
        if (key === 'event_id') return 'dl_event_id_abc123';
        return undefined;
      });
      let result = runCode({ttl: 8000});
      assertThat(result).isEqualTo('dl_event_id_abc123');
  - name: 'generates new id starting with evt_ when dataLayer is empty'
    code: |-
      mock('copyFromDataLayer', function() { return undefined; });
      mock('copyFromWindow', function() { return undefined; });
      mock('setInWindow', function() {});
      mock('getTimestampMillis', function() { return 1700000000000; });
      mock('generateRandom', function() { return 42; });
      mock('getUrl', function(part) { return part === 'path' ? '/test' : ''; });
      let result = runCode({ttl: 8000});
      assertThat(result).isEqualTo('evt_1700000000000_42');
  - name: 'returns cached id within TTL for same event+route'
    code: |-
      let cache = {};
      mock('copyFromDataLayer', function() { return undefined; });
      mock('copyFromWindow', function(key) {
        return key === '_tapiEventIdCache' ? cache : undefined;
      });
      mock('setInWindow', function(key, val) { cache = val; });
      mock('getTimestampMillis', function() { return 1700000000000; });
      mock('generateRandom', function() { return 99; });
      mock('getUrl', function(part) { return part === 'path' ? '/home' : ''; });
      let firstResult = runCode({ttl: 8000});
      mock('generateRandom', function() { return 100; });
      let secondResult = runCode({ttl: 8000});
      assertThat(firstResult).isEqualTo(secondResult);


___NOTES___

TrackAPI - Event ID - GTM Variable Template (v2)

Returns the event_id for Meta Pixel deduplication with TrackAPI CAPI.

Priority:
1. Reads event_id from the current dataLayer push (SPA/Next.js with
   PageViewTracker or trackEvent() — the push already contains event_id)
2. Falls back to generating a new id with per-event+route cache (traditional
   sites with autoPageView: true — no event_id in the push)

This ensures the FB Pixel browser tag and TrackAPI CAPI always use the same
event_id, regardless of project type.

How to use:
1. Import this template as a Variable in GTM
2. In the Facebook Pixel tag, set Event ID to {{TrackAPI - Event ID}}
3. TrackAPI SDK reads the same event_id from dataLayer and sends it to CAPI

Documentation: https://trackapi.app.br/docs/sdk


