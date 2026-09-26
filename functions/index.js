// Missed-dose call sketch. The phone posts medicine names here.
// Twilio's auth token belongs in Functions config (process.env.TWILIO_AUTH_TOKEN),
// never in this file and never in the app. Do not deploy until asked.

'use strict';

const SECRET_HEADER = 'x-rapidrx-secret';

function xml(raw) {
  return String(raw)
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;')
    .replaceAll("'", '&apos;');
}

function namesOnly(medicines) {
  if (!Array.isArray(medicines)) return [];
  return medicines
    .filter((name) => typeof name === 'string' && name.trim() !== '')
    .map((name) => name.trim());
}

function sayLanguage(language) {
  const code = String(language || 'en').toLowerCase();
  return code.startsWith('hi') ? 'hi-IN' : 'en-IN';
}

/** Same words as lib/features/calls/dose_twiml.dart. Names only. */
function buildTwiml({ language, medicines, gatherUrl }) {
  const names = namesOnly(medicines).join(', ');
  const lang = sayLanguage(language);
  const hindi = lang === 'hi-IN';
  const intro = hindi
    ? `नमस्ते। RapidRX से, यह एक ऑटोमैटिक कॉल है। आपकी दवाई: ${names}।`
    : `Hello. This is an automatic call from RapidRX. Your medicine: ${names}.`;
  const ask = hindi
    ? 'ले ली है तो 1 दबाइए। अभी नहीं तो 2। परिवार को बताना है तो 9।'
    : 'Press 1 if taken. Press 2 for later. Press 9 to tell your family.';
  const action = gatherUrl || '/gather';
  return (
    '<?xml version="1.0" encoding="UTF-8"?>\n' +
    '<Response>\n' +
    `  <Say language="${lang}">${xml(intro)}</Say>\n` +
    `  <Gather numDigits="1" timeout="8" action="${xml(action)}" method="POST">\n` +
    `    <Say language="${lang}">${xml(ask)}</Say>\n` +
    '  </Gather>\n' +
    '</Response>\n'
  );
}

function header(req, name) {
  const headers = req.headers || {};
  const wanted = name.toLowerCase();
  for (const key of Object.keys(headers)) {
    if (key.toLowerCase() === wanted) return String(headers[key] ?? '');
  }
  return '';
}

/**
 * App request: shared-secret header, then TwiML built from medicine names.
 * Gather webhook: returns the digit. It does not write a dose.
 */
function handle(req) {
  const expected = process.env.RAPIDRX_CALL_SECRET || '';
  const got = header(req, SECRET_HEADER);
  if (!expected || got !== expected) {
    return { status: 401, body: 'unauthorized' };
  }
  const body = req.body || {};
  const url = req.url || '/';
  if (url.includes('gather') || Object.prototype.hasOwnProperty.call(body, 'Digits')) {
    const digit = body.Digits == null ? '' : String(body.Digits);
    return { status: 200, json: { digit } };
  }
  return {
    status: 200,
    contentType: 'text/xml',
    body: buildTwiml({
      language: body.language,
      medicines: body.medicines,
      gatherUrl: '/gather',
    }),
  };
}

function send(res, result) {
  res.status(result.status);
  if (result.json) {
    res.json(result.json);
    return;
  }
  if (result.contentType) res.type(result.contentType);
  res.send(result.body || '');
}

try {
  const { onRequest } = require('firebase-functions/v2/https');
  exports.doseCall = onRequest((req, res) => {
    send(res, handle({ headers: req.headers, body: req.body, url: req.path }));
  });
} catch (error) {
  if (error.code !== 'MODULE_NOT_FOUND') throw error;
}

module.exports = { buildTwiml, handle, namesOnly };
