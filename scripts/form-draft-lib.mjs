/** @typedef {{ rowId: string, colKey: string }} ParsedRowField */

export const DEFAULT_EXCLUDED = new Set(['document_changes', 'significant_change'])

/**
 * @param {string} name
 * @returns {ParsedRowField | null}
 */
export function parseRowFieldName(name) {
  const match = /^rows\[([^\]]+)\]\[([^\]]+)\]$/.exec(name)
  if (!match) return null
  return { rowId: match[1], colKey: match[2] }
}

/**
 * @param {{ type?: string, checked?: boolean, value?: string }} field
 */
export function fieldValue(field) {
  if (field.type === 'checkbox') {
    return field.checked ? field.value || '1' : '0'
  }
  return field.value ?? ''
}

/**
 * @param {Array<{ name: string, type?: string, checked?: boolean, value?: string }>} entries
 * @param {Set<string>} excluded
 */
export function captureTextState(entries, excluded = DEFAULT_EXCLUDED) {
  /** @type {Record<string, string>} */
  const state = {}
  const checkboxNames = new Set(
    entries.filter((entry) => entry.type === 'checkbox' && entry.name).map((entry) => entry.name)
  )

  entries.forEach((entry) => {
    const name = entry.name
    if (!name || excluded.has(name)) return
    if (entry.type === 'hidden' && checkboxNames.has(name)) return
    state[name] = fieldValue(entry)
  })

  return state
}

/**
 * @param {Array<{ name: string, type?: string, checked?: boolean, value?: string }>} entries
 */
export function captureTableState(entries) {
  /** @type {Record<string, Record<string, string>>} */
  const rows = {}
  const checkboxNames = new Set(
    entries.filter((entry) => entry.type === 'checkbox' && entry.name).map((entry) => entry.name)
  )

  entries.forEach((entry) => {
    const parsed = parseRowFieldName(entry.name || '')
    if (!parsed) return
    if (entry.type === 'hidden' && checkboxNames.has(entry.name)) return
    if (!rows[parsed.rowId]) rows[parsed.rowId] = {}
    rows[parsed.rowId][parsed.colKey] = fieldValue(entry)
  })

  return { rows }
}

/**
 * @param {unknown} a
 * @param {unknown} b
 */
export function statesEqual(a, b) {
  return JSON.stringify(a) === JSON.stringify(b)
}

/**
 * @param {unknown} state
 * @param {unknown} baseline
 */
export function isDirty(state, baseline) {
  return !statesEqual(state, baseline)
}
