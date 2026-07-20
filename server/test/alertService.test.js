const assert = require('node:assert/strict');
const test = require('node:test');

const { resolveClassificationSource } = require('../services/alertService');

// Regression test for a production incident: alerts.classification_source is
// NOT NULL DEFAULT 'user' in Postgres, but the quick-SOS path (no free-text
// report data at all) was passing an explicit null through to the insert,
// which overrides the column default and violates the constraint -- every
// plain SOS trigger failed with a 500 until this was fixed.

test('plain quick-SOS trigger (no classification data at all) resolves to "user", never null', () => {
  const source = resolveClassificationSource({
    confirmedCategory: undefined,
    suggestedCategory: undefined,
    classificationSource: undefined,
  });

  assert.equal(source, 'user');
  assert.notEqual(source, null);
});

test('free-text report: user accepts the AI/rules suggestion unmodified keeps that source', () => {
  assert.equal(
    resolveClassificationSource({
      confirmedCategory: 'fire',
      suggestedCategory: 'fire',
      classificationSource: 'ai',
    }),
    'ai'
  );

  assert.equal(
    resolveClassificationSource({
      confirmedCategory: 'fire',
      suggestedCategory: 'fire',
      classificationSource: 'rules',
    }),
    'rules'
  );
});

test('free-text report: user edits the suggested category away from what was suggested becomes "user"', () => {
  assert.equal(
    resolveClassificationSource({
      confirmedCategory: 'medical_emergency',
      suggestedCategory: 'fire',
      classificationSource: 'ai',
    }),
    'user'
  );
});
