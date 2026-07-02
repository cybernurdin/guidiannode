const assert = require('node:assert/strict');
const test = require('node:test');
const { normalizePhoneNumber } = require('../utils/authUtils');

test('phone normalization matches Cameroonian formats to standard national digits', () => {
  const expected = '237677034736';
  
  assert.equal(normalizePhoneNumber('677034736'), expected);
  assert.equal(normalizePhoneNumber('+237677034736'), expected);
  assert.equal(normalizePhoneNumber('237677034736'), expected);
  assert.equal(normalizePhoneNumber('+237 6 77 03 47 36'), expected);
  assert.equal(normalizePhoneNumber('+237657262038'), '237657262038');
});
