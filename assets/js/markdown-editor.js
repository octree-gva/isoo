const wrapped = new WeakSet()

function isMarkdownTextarea(textarea) {
  return textarea instanceof HTMLTextAreaElement &&
    textarea.matches('[data-markdown-editor]') &&
    textarea.dataset.plainTextarea !== 'true'
}

export function shouldMount(textarea) {
  if (!isMarkdownTextarea(textarea)) return false
  if (textarea.closest('.markdown-editor')) return false
  return true
}

function isVisible(textarea) {
  if (!textarea?.isConnected) return false
  if (textarea.closest('[hidden]')) return false
  const step = textarea.closest('[data-wizard-step]')
  if (step?.hidden) return false
  return textarea.offsetParent !== null || textarea.getClientRects().length > 0
}

function lineRange(value, start, end) {
  const lineStart = value.lastIndexOf('\n', start - 1) + 1
  const nextBreak = value.indexOf('\n', end)
  const lineEnd = nextBreak === -1 ? value.length : nextBreak
  return [lineStart, lineEnd]
}

function wrapSelection(textarea, before, after) {
  const { selectionStart: start, selectionEnd: end, value } = textarea
  const selected = value.slice(start, end)
  const inserted = before + selected + after
  textarea.setRangeText(inserted, start, end, 'end')
  const cursor = start + inserted.length
  textarea.focus()
  textarea.setSelectionRange(cursor, cursor)
}

function prefixLines(textarea, prefix) {
  const { selectionStart: start, selectionEnd: end, value } = textarea
  const [lineStart, lineEnd] = lineRange(value, start, end)
  const block = value.slice(lineStart, lineEnd)
  const lines = block.length ? block.split('\n') : ['']
  const prefixed = lines.map((line) => prefix + line).join('\n')
  textarea.setRangeText(prefixed, lineStart, lineEnd, 'end')
  textarea.focus()
  const cursor = Math.max(lineStart + prefix.length, start + prefix.length)
  textarea.setSelectionRange(cursor, cursor)
}

function buildToolbar(textarea) {
  const bar = document.createElement('div')
  bar.className = 'markdown-editor__toolbar'
  bar.setAttribute('role', 'toolbar')
  bar.setAttribute('aria-label', 'Formatting')

  const items = [
    ['Bold', 'ri-bold', () => wrapSelection(textarea, '**', '**')],
    ['Italic', 'ri-italic', () => wrapSelection(textarea, '*', '*')],
    ['Heading', 'ri-h-2', () => prefixLines(textarea, '## ')],
    ['Bullet list', 'ri-list-unordered', () => prefixLines(textarea, '- ')],
    ['Numbered list', 'ri-list-ordered', () => prefixLines(textarea, '1. ')],
  ]

  items.forEach(([label, icon, action]) => {
    const btn = document.createElement('button')
    btn.type = 'button'
    btn.className = 'markdown-editor__btn'
    btn.setAttribute('aria-label', label)
    btn.setAttribute('title', label)
    btn.innerHTML = '<i class="' + icon + '" aria-hidden="true"></i>'
    btn.addEventListener('mousedown', (event) => event.preventDefault())
    btn.addEventListener('click', (event) => {
      event.preventDefault()
      action()
    })
    bar.appendChild(btn)
  })

  return bar
}

export function mount(textarea) {
  if (wrapped.has(textarea)) return textarea
  if (!shouldMount(textarea)) return null

  const rows = parseInt(textarea.getAttribute('rows') || '6', 10)
  const minHeight = Math.max(rows * 1.5, 6) + 'rem'

  const shell = document.createElement('div')
  shell.className = 'markdown-editor textarea-bordered w-full'
  textarea.parentNode.insertBefore(shell, textarea)
  shell.appendChild(buildToolbar(textarea))
  shell.appendChild(textarea)

  textarea.classList.add('markdown-editor__input')
  textarea.classList.remove('textarea-bordered', 'w-full')
  textarea.style.minHeight = minHeight

  wrapped.add(textarea)
  return textarea
}

export function unmount(textarea) {
  if (!wrapped.has(textarea)) return

  const shell = textarea.closest('.markdown-editor')
  if (!shell) {
    wrapped.delete(textarea)
    return
  }

  textarea.classList.remove('markdown-editor__input')
  textarea.classList.add('textarea-bordered', 'w-full')
  textarea.style.minHeight = ''
  shell.parentNode.insertBefore(textarea, shell)
  shell.remove()
  wrapped.delete(textarea)
}

export function unmountAll(root) {
  const scope = root || document
  scope.querySelectorAll('textarea[data-markdown-editor]').forEach((ta) => {
    if (wrapped.has(ta)) unmount(ta)
  })
}

export function mountVisible(root) {
  const scope = root || document
  scope.querySelectorAll('textarea[data-markdown-editor]').forEach((ta) => {
    if (isVisible(ta)) mount(ta)
  })
}

export function initAll(root) {
  mountVisible(root)
}

export function bindLazyEditors(root) {
  if (root && root !== document && root.__isooMarkdownBound) return
  if (root && root !== document) root.__isooMarkdownBound = true
  if (!root || root === document) {
    if (document.documentElement.dataset.isooMarkdownLazyBound) return
    document.documentElement.dataset.isooMarkdownLazyBound = 'true'
  }
}

export function syncAll(_root) {
  /* Native textarea — value is always current. */
}

export function setValue(textarea, value) {
  textarea.value = value || ''
}

export function focusEditor(textarea) {
  if (!isMarkdownTextarea(textarea)) return false
  mount(textarea)
  textarea.focus()
  return true
}

const api = {
  mount,
  unmount,
  unmountAll,
  mountVisible,
  initAll,
  bindLazyEditors,
  syncAll,
  setValue,
  focusEditor,
  shouldMount,
}

if (typeof window !== 'undefined') {
  window.IsooMarkdownEditor = api

  function boot() {
    bindLazyEditors()
    mountVisible(document)
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', boot)
  } else {
    boot()
  }
}

export default api
