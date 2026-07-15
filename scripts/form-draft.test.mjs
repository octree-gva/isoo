import assert from 'node:assert/strict'
import {
  DEFAULT_EXCLUDED,
  captureTableState,
  captureTextState,
  fieldValue,
  isDirty,
  parseRowFieldName,
  statesEqual,
} from './form-draft-lib.mjs'

assert.deepEqual(parseRowFieldName('rows[abc][title]'), { rowId: 'abc', colKey: 'title' })
assert.equal(parseRowFieldName('about_us'), null)

assert.equal(fieldValue({ type: 'checkbox', checked: true, value: '1' }), '1')
assert.equal(fieldValue({ type: 'checkbox', checked: false, value: '1' }), '0')
assert.equal(fieldValue({ type: 'text', value: 'hello' }), 'hello')

const textEntries = [
  { name: 'about_us', type: 'textarea', value: 'draft text' },
  { name: 'document_changes', type: 'textarea', value: 'ignored' },
  { name: 'enabled', type: 'hidden', value: '0' },
  { name: 'enabled', type: 'checkbox', checked: true, value: '1' },
]

assert.deepEqual(captureTextState(textEntries), {
  about_us: 'draft text',
  enabled: '1',
})
assert.deepEqual(captureTextState(textEntries, DEFAULT_EXCLUDED), {
  about_us: 'draft text',
  enabled: '1',
})

const tableEntries = [
  { name: 'rows[r1][standard]', type: 'text', value: 'GDPR' },
  { name: 'rows[r1][active]', type: 'hidden', value: '0' },
  { name: 'rows[r1][active]', type: 'checkbox', checked: false, value: '1' },
]

assert.deepEqual(captureTableState(tableEntries), {
  rows: {
    r1: { standard: 'GDPR', active: '0' },
  },
})

const baseline = { about_us: 'saved' }
const draft = { about_us: 'edited' }
assert.equal(isDirty(draft, baseline), true)
assert.equal(isDirty(baseline, baseline), false)
assert.equal(statesEqual({ rows: { a: { x: '1' } } }, { rows: { a: { x: '1' } } }), true)

console.log('form-draft tests passed')
