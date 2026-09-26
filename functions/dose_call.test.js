const { test } = require('node:test');
const assert = require('node:assert/strict');
const { buildTwiml, handle } = require('./index.js');

test('TwiML says the medicine name and gathers 1, 2, 9', () => {
  const xml = buildTwiml({
    language: 'hi',
    medicines: ['TELMA 40'],
    gatherUrl: '/gather',
  });
  assert.match(xml, /TELMA 40/);
  assert.match(xml, /language="hi-IN"/);
  assert.match(xml, /<Gather numDigits="1"/);
  assert.match(xml, /1/);
  assert.match(xml, /2/);
  assert.match(xml, /9/);
  assert.doesNotMatch(xml, /transcript/);
});

test('a notes field on the request is not spoken', () => {
  process.env.RAPIDRX_CALL_SECRET = 'test-secret';
  const result = handle({
    headers: { 'x-rapidrx-secret': 'test-secret' },
    body: {
      language: 'en',
      medicines: ['TELMA 40'],
      notes: 'take for blood pressure',
      transcript: 'the doctor said something else',
    },
    url: '/dose',
  });
  assert.equal(result.status, 200);
  assert.match(result.body, /TELMA 40/);
  assert.doesNotMatch(result.body, /blood pressure/);
  assert.doesNotMatch(result.body, /something else/);
});

test('a missing secret is rejected', () => {
  process.env.RAPIDRX_CALL_SECRET = 'test-secret';
  const result = handle({
    headers: {},
    body: { medicines: ['TELMA 40'] },
    url: '/dose',
  });
  assert.equal(result.status, 401);
});

test('the gather webhook returns the digit and does not invent one', () => {
  process.env.RAPIDRX_CALL_SECRET = 'test-secret';
  const pressed = handle({
    headers: { 'X-RapidRX-Secret': 'test-secret' },
    body: { Digits: '1' },
    url: '/gather',
  });
  assert.deepEqual(pressed.json, { digit: '1' });

  const silence = handle({
    headers: { 'X-RapidRX-Secret': 'test-secret' },
    body: { Digits: '' },
    url: '/gather',
  });
  assert.deepEqual(silence.json, { digit: '' });
});
