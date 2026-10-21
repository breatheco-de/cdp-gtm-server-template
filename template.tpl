___TERMS_OF_SERVICE___

By creating or modifying this file you agree to Google Tag Manager's Community
Template Gallery Developer Terms of Service available at
https://developers.google.com/tag-manager/gallery-tos (or such other URL as
Google may provide), as modified from time to time.


___INFO___

{
  "type": "TAG",
  "id": "cvt_temp_public_id",
  "version": 1,
  "securityGroups": [],
  "displayName": "4Geeks CDP",
  "categories": [
    "ANALYTICS",
    "LEAD_GENERATION",
    "PERSONALIZATION"
  ],
  "brand": {
    "id": "brand_dummy",
    "displayName": "4Geeks"
  },
  "description": "Sends server-side events to the 4Geeks Customer Data Platform (POST /v1/track) with an ingest-only token. Maps GA4 client_id, user_id and user_data email/phone to CDP identifiers.",
  "containerContexts": [
    "SERVER"
  ]
}


___TEMPLATE_PARAMETERS___

[
  {
    "type": "TEXT",
    "name": "apiUrl",
    "displayName": "CDP endpoint",
    "simpleValueType": true,
    "defaultValue": "https://cdp.4geeks.us/v1/track",
    "help": "The track endpoint shown on Agent tokens when you choose Server-side GTM.",
    "valueValidators": [
      {
        "type": "NON_EMPTY"
      },
      {
        "type": "REGEX",
        "args": [
          "^https://.+/v1/track$"
        ],
        "errorMessage": "Use the https address that ends in /v1/track."
      }
    ]
  },
  {
    "type": "TEXT",
    "name": "token",
    "displayName": "Ingest token",
    "simpleValueType": true,
    "help": "Mint it on Agent tokens → Connect → Server-side GTM. It can only send events.",
    "valueValidators": [
      {
        "type": "NON_EMPTY"
      },
      {
        "type": "REGEX",
        "args": [
          "^cdp_.+"
        ],
        "errorMessage": "CDP tokens start with cdp_."
      }
    ]
  },
  {
    "type": "TEXT",
    "name": "eventName",
    "displayName": "Event name override",
    "simpleValueType": true,
    "help": "Leave empty to send the GA4 event name as it is (link it to the CDP's names under Event names). Type a fixed name, or pick a variable such as a Lookup Table to rename several events. Names can't start with $."
  },
  {
    "type": "CHECKBOX",
    "name": "sendUnknown",
    "checkboxText": "Send visitors we don't know yet",
    "simpleValueType": true,
    "defaultValue": true,
    "help": "On: events with only Google's browser ID create a nameless profile that joins the person once an email, phone or user ID arrives with the same browser ID. Off: those events are only kept when the browser already belongs to someone."
  },
  {
    "type": "GROUP",
    "name": "identity",
    "displayName": "Who the event is about",
    "groupStyle": "ZIPPY_CLOSED",
    "subParams": [
      {
        "type": "TEXT",
        "name": "email",
        "displayName": "Email",
        "simpleValueType": true,
        "help": "Empty: user_data.email_address from the event. Scrambled (hashed) or invalid emails are dropped and the rest of the event is still sent."
      },
      {
        "type": "TEXT",
        "name": "userId",
        "displayName": "User ID",
        "simpleValueType": true,
        "help": "Empty: user_id from the event."
      },
      {
        "type": "TEXT",
        "name": "phone",
        "displayName": "Phone",
        "simpleValueType": true,
        "help": "Empty: user_data.phone_number from the event."
      }
    ]
  },
  {
    "type": "GROUP",
    "name": "advanced",
    "displayName": "Advanced",
    "groupStyle": "ZIPPY_CLOSED",
    "subParams": [
      {
        "type": "TEXT",
        "name": "skipEvents",
        "displayName": "Events to skip",
        "simpleValueType": true,
        "defaultValue": "session_start, first_visit, user_engagement, scroll",
        "help": "Comma-separated GA4 event names the tag never sends. Clear it to send everything the trigger fires on."
      },
      {
        "type": "CHECKBOX",
        "name": "sendAllParams",
        "checkboxText": "Send all event parameters as properties",
        "simpleValueType": true,
        "defaultValue": true
      },
      {
        "type": "TEXT",
        "name": "source",
        "displayName": "Source",
        "simpleValueType": true,
        "defaultValue": "gtm_server",
        "help": "Shown as \"via …\" on the CDP Ingest page. The same event ID from the same source is stored once."
      },
      {
        "type": "CHECKBOX",
        "name": "sendAsTest",
        "checkboxText": "Send as test (for staging containers)",
        "simpleValueType": true,
        "defaultValue": false,
        "help": "New profiles are marked as test and stay out of real numbers and campaigns. Events sent while GTM preview is on are always marked as test."
      }
    ]
  }
]


___SANDBOXED_JS_FOR_SERVER___

const getAllEventData = require('getAllEventData');
const getContainerVersion = require('getContainerVersion');
const getType = require('getType');
const JSON = require('JSON');
const logToConsole = require('logToConsole');
const makeString = require('makeString');
const Object = require('Object');
const sendHttpRequest = require('sendHttpRequest');

const RESERVED_PREFIX = '$';
const NOT_PROPERTIES = {
  event_name: true,
  event_id: true,
  client_id: true,
  user_id: true,
  user_data: true,
  ip_override: true,
  user_agent: true
};

const eventData = getAllEventData() || {};
const userData = getType(eventData.user_data) === 'object' ? eventData.user_data : {};
const container = getContainerVersion() || {};
const inPreview = !!(container.previewMode || container.debugMode);

function log(message, value) {
  logToConsole('4Geeks CDP: ' + message, value);
}

function text(value) {
  if (value === undefined || value === null) return undefined;
  const s = makeString(value).trim();
  return s ? s : undefined;
}

function isEmail(value) {
  if (!value || value.length > 254 || value.indexOf(' ') !== -1) return false;
  const at = value.indexOf('@');
  if (at < 1 || at !== value.lastIndexOf('@')) return false;
  const domain = value.substring(at + 1);
  const dot = domain.lastIndexOf('.');
  return dot > 0 && dot < domain.length - 1;
}

function skipList() {
  const raw = data.skipEvents === undefined ? 'session_start, first_visit, user_engagement, scroll' : makeString(data.skipEvents || '');
  return raw
    .split(',')
    .map(function (name) { return name.trim(); })
    .filter(function (name) { return name.length > 0; });
}

const gaName = text(eventData.event_name);
if (gaName && skipList().indexOf(gaName) !== -1) {
  log('skipped background event', gaName);
  data.gtmOnSuccess();
  return;
}

const eventName = text(data.eventName) || gaName;
if (!eventName) {
  log('no event name; nothing sent', eventData);
  data.gtmOnFailure();
  return;
}
if (eventName.indexOf(RESERVED_PREFIX) === 0) {
  log('event names starting with $ are reserved by the CDP', eventName);
  data.gtmOnFailure();
  return;
}

let email = text(data.email) || text(userData.email_address);
if (email && !isEmail(email)) {
  log('dropped an email that is not a valid address (hashed?)', email);
  email = undefined;
}
const userId = text(data.userId) || text(eventData.user_id);
const phone = text(data.phone) || text(userData.phone_number);
const anonymousId = text(eventData.client_id);

if (!email && !userId && !phone && !anonymousId) {
  log('no identifier on this event; nothing sent', eventData);
  data.gtmOnSuccess();
  return;
}

const known = !!(email || userId || phone);
const body = {
  event: eventName,
  source: text(data.source) || 'gtm_server',
  createProfile: known || data.sendUnknown !== false
};
if (email) body.email = email.toLowerCase();
if (userId) body.userId = userId;
if (phone) body.phone = phone;
if (anonymousId) body.anonymousId = anonymousId;
const eventId = text(eventData.event_id);
if (eventId) body.eventId = eventId;
if (data.sendAsTest || inPreview) body.isTest = true;

if (data.sendAllParams !== false) {
  const properties = {};
  Object.keys(eventData).forEach(function (key) {
    if (NOT_PROPERTIES[key] || key.indexOf('x-') === 0) return;
    properties[key] = eventData[key];
  });
  if (gaName && gaName !== eventName) properties.ga_event_name = gaName;
  body.properties = properties;
}

sendHttpRequest(
  data.apiUrl,
  {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      Authorization: 'Bearer ' + data.token
    },
    timeout: 5000
  },
  JSON.stringify(body)
).then(function (result) {
  if (result.statusCode >= 200 && result.statusCode < 300) {
    if (inPreview) log('sent ' + eventName, result.body);
    data.gtmOnSuccess();
  } else {
    log('CDP answered ' + result.statusCode, result.body);
    data.gtmOnFailure();
  }
}, function (error) {
  log('request failed', error);
  data.gtmOnFailure();
});


___SERVER_PERMISSIONS___

[
  {
    "instance": {
      "key": {
        "publicId": "read_event_data",
        "versionId": "1"
      },
      "param": [
        {
          "key": "eventDataAccess",
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
  },
  {
    "instance": {
      "key": {
        "publicId": "read_container_data",
        "versionId": "1"
      },
      "param": []
    },
    "isRequired": true
  },
  {
    "instance": {
      "key": {
        "publicId": "send_http",
        "versionId": "1"
      },
      "param": [
        {
          "key": "allowedUrls",
          "value": {
            "type": 1,
            "string": "specific"
          }
        },
        {
          "key": "urls",
          "value": {
            "type": 2,
            "listItem": [
              {
                "type": 1,
                "string": "https://cdp.4geeks.us/*"
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
        "publicId": "logging",
        "versionId": "1"
      },
      "param": [
        {
          "key": "environments",
          "value": {
            "type": 1,
            "string": "debug"
          }
        }
      ]
    },
    "isRequired": true
  }
]


___TESTS___

scenarios:
- name: Maps GA4 identifiers and sends the event
  code: |-
    mockData.token = 'cdp_test';
    runCode(mockData);
    assertApi('sendHttpRequest').wasCalled();
    assertThat(sent.url).isEqualTo('https://cdp.4geeks.us/v1/track');
    assertThat(sent.options.headers.Authorization).isEqualTo('Bearer cdp_test');
    assertThat(sent.body.event).isEqualTo('sign_up');
    assertThat(sent.body.email).isEqualTo('ana@example.com');
    assertThat(sent.body.userId).isEqualTo('u-1');
    assertThat(sent.body.anonymousId).isEqualTo('cid.123');
    assertThat(sent.body.source).isEqualTo('gtm_server');
    assertThat(sent.body.createProfile).isEqualTo(true);
    assertThat(sent.body.properties.page_location).isEqualTo('https://example.com/join');
    assertThat(sent.body.properties.client_id).isUndefined();
    assertThat(sent.body.properties['x-ga-protocol_version']).isUndefined();
    assertThat(sent.body.isTest).isUndefined();
    assertApi('gtmOnSuccess').wasCalled();
- name: Skips Google's background events
  code: |-
    eventData.event_name = 'scroll';
    runCode(mockData);
    assertApi('sendHttpRequest').wasNotCalled();
    assertApi('gtmOnSuccess').wasCalled();
- name: Sends everything when the skip list is cleared
  code: |-
    eventData.event_name = 'scroll';
    mockData.skipEvents = '';
    runCode(mockData);
    assertApi('sendHttpRequest').wasCalled();
    assertThat(sent.body.event).isEqualTo('scroll');
- name: Drops a hashed email and still sends the event
  code: |-
    eventData.user_data.email_address = 'a665a45920422f9d417e4867efdc4fb8a04a1f3fff1fa07e998e86f7f7a27ae3';
    runCode(mockData);
    assertThat(sent.body.email).isUndefined();
    assertThat(sent.body.userId).isEqualTo('u-1');
    assertApi('gtmOnSuccess').wasCalled();
- name: Unknown visitors only stick to known browsers when the switch is off
  code: |-
    eventData.user_id = undefined;
    eventData.user_data = {};
    mockData.sendUnknown = false;
    runCode(mockData);
    assertThat(sent.body.anonymousId).isEqualTo('cid.123');
    assertThat(sent.body.createProfile).isEqualTo(false);
- name: Known people are always created even with the switch off
  code: |-
    mockData.sendUnknown = false;
    runCode(mockData);
    assertThat(sent.body.createProfile).isEqualTo(true);
- name: Renames the event with the override
  code: |-
    mockData.eventName = 'platform_signed_up';
    runCode(mockData);
    assertThat(sent.body.event).isEqualTo('platform_signed_up');
    assertThat(sent.body.properties.ga_event_name).isEqualTo('sign_up');
- name: Refuses reserved event names
  code: |-
    mockData.eventName = '$identify';
    runCode(mockData);
    assertApi('sendHttpRequest').wasNotCalled();
    assertApi('gtmOnFailure').wasCalled();
- name: Marks events as test in GTM preview
  code: |-
    container.previewMode = true;
    runCode(mockData);
    assertThat(sent.body.isTest).isEqualTo(true);
- name: Fails the tag when the CDP refuses the request
  code: |-
    status = 401;
    runCode(mockData);
    assertApi('gtmOnFailure').wasCalled();
setup: |-
  const JSON = require('JSON');
  const Promise = require('Promise');

  const mockData = {
    apiUrl: 'https://cdp.4geeks.us/v1/track',
    token: 'cdp_test',
    sendUnknown: true,
    sendAllParams: true,
    source: 'gtm_server',
    skipEvents: 'session_start, first_visit, user_engagement, scroll',
    sendAsTest: false
  };

  const eventData = {
    event_name: 'sign_up',
    client_id: 'cid.123',
    user_id: 'u-1',
    user_data: { email_address: 'Ana@Example.com' },
    page_location: 'https://example.com/join',
    'x-ga-protocol_version': '2'
  };

  const container = { previewMode: false, debugMode: false };
  let status = 200;
  let sent = {};

  mock('getAllEventData', function () { return eventData; });
  mock('getContainerVersion', function () { return container; });
  mock('sendHttpRequest', function (url, options, body) {
    sent = { url: url, options: options, body: JSON.parse(body) };
    return Promise.create(function (resolve) {
      resolve({ statusCode: status, headers: {}, body: '{"profile":{}}' });
    });
  });


___NOTES___

Server-side tag for the 4Geeks CDP. Source: https://github.com/breatheco-de/cdp-gtm-server-template
