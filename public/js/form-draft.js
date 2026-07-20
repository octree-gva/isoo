(function () {
  var DEBOUNCE_MS = 400;

  function t(key, fallback) {
    var node = window.I18n;
    if (!node) return fallback;
    var parts = key.split('.');
    for (var i = 0; i < parts.length; i++) {
      node = node[parts[i]];
      if (node == null) return fallback;
    }
    return typeof node === 'string' ? node : fallback;
  }

  function parseRowFieldName(name) {
    var match = /^rows\[([^\]]+)\]\[([^\]]+)\]$/.exec(name);
    if (!match) return null;
    return { rowId: match[1], colKey: match[2] };
  }

  function fieldValue(el) {
    if (el.type === 'checkbox') {
      return el.checked ? el.value || '1' : '0';
    }
    return el.value == null ? '' : el.value;
  }

  function setFieldValue(el, value) {
    if (el.type === 'checkbox') {
      el.checked = ['1', 'true', 'yes', 'on'].includes(String(value).toLowerCase());
    } else if (el.matches('[data-markdown-editor]') && window.IsooMarkdownEditor) {
      window.IsooMarkdownEditor.setValue(el, value);
    } else {
      el.value = value || '';
    }
  }

  function trackedFields(root) {
    return root.querySelectorAll('[data-draft-track]');
  }

  function updateFieldDirty(el) {
    var pristine = el.getAttribute('data-pristine');
    if (pristine == null) pristine = '';
    var dirty = fieldValue(el) !== pristine;
    el.setAttribute('data-dirty', dirty ? 'true' : 'false');
    return dirty;
  }

  function snapshotPristine(form) {
    trackedFields(form).forEach(function (el) {
      el.setAttribute('data-pristine', fieldValue(el));
      el.setAttribute('data-dirty', 'false');
    });
  }

  function refreshDirty(form) {
    trackedFields(form).forEach(updateFieldDirty);
  }

  function formIsDirty(form) {
    return !!form.querySelector('[data-draft-track][data-dirty="true"]');
  }

  function captureTrackedState(form, mode) {
    if (mode === 'table') {
      var rows = {};
      trackedFields(form).forEach(function (el) {
        var parsed = parseRowFieldName(el.name || '');
        if (!parsed) return;
        if (!rows[parsed.rowId]) rows[parsed.rowId] = {};
        rows[parsed.rowId][parsed.colKey] = fieldValue(el);
      });
      return { rows: rows };
    }

    var state = {};
    trackedFields(form).forEach(function (el) {
      if (!el.name) return;
      state[el.name] = fieldValue(el);
    });
    return state;
  }

  function applyTextState(form, state) {
    if (!state) return;
    trackedFields(form).forEach(function (el) {
      if (!el.name || !Object.prototype.hasOwnProperty.call(state, el.name)) return;
      setFieldValue(el, state[el.name]);
    });
  }

  function applyTableState(form, state) {
    if (!state || !state.rows) return;
    trackedFields(form).forEach(function (el) {
      var parsed = parseRowFieldName(el.name || '');
      if (!parsed || !state.rows[parsed.rowId]) return;
      if (!Object.prototype.hasOwnProperty.call(state.rows[parsed.rowId], parsed.colKey)) return;
      setFieldValue(el, state.rows[parsed.rowId][parsed.colKey]);
    });
  }

  function applyFormState(form, state, mode) {
    if (mode === 'table') applyTableState(form, state);
    else applyTextState(form, state);
    if (window.IsooMarkdownEditor) window.IsooMarkdownEditor.mountVisible(form);
    refreshDirty(form);
  }

  function statesEqual(a, b) {
    return JSON.stringify(a) === JSON.stringify(b);
  }

  function showToast(message) {
    var existing = document.querySelector('[data-toast-draft]');
    if (existing) existing.remove();

    var wrap = document.createElement('div');
    wrap.className = 'toast toast-top toast-end z-[60] pointer-events-none';
    wrap.setAttribute('role', 'status');
    wrap.setAttribute('aria-live', 'polite');
    wrap.setAttribute('data-toast-draft', '1');

    var alert = document.createElement('div');
    alert.className =
      'alert alert-info shadow-lg max-w-md pointer-events-auto flex items-start gap-3';

    var icon = document.createElement('i');
    icon.className = 'ri-information-line text-xl shrink-0';
    icon.setAttribute('aria-hidden', 'true');

    var text = document.createElement('span');
    text.className = 'flex-1 text-base';
    text.textContent = message;

    var dismiss = document.createElement('button');
    dismiss.type = 'button';
    dismiss.className = 'btn btn-ghost btn-xs btn-circle shrink-0';
    dismiss.setAttribute('aria-label', t('toast.dismiss', 'Dismiss notification'));
    dismiss.innerHTML = '<i class="ri-close-line" aria-hidden="true"></i>';

    alert.appendChild(icon);
    alert.appendChild(text);
    alert.appendChild(dismiss);
    wrap.appendChild(alert);
    document.body.appendChild(wrap);

    function dismissToast() {
      wrap.style.opacity = '0';
      wrap.style.transition = 'opacity 0.3s ease';
      window.setTimeout(function () {
        wrap.remove();
      }, 300);
    }

    dismiss.addEventListener('click', dismissToast);
    window.setTimeout(dismissToast, 5000);
  }

  function bind(form) {
    var storageKey = form.getAttribute('data-form-draft');
    if (!storageKey) return;

    var mode = form.getAttribute('data-draft-mode') || 'text';
    var saveModalId = form.getAttribute('data-leave-save-modal') || 'save_modal';
    var leaveModal = document.getElementById('leave_modal');
    var pendingHref = null;
    var debounceTimer = null;
    var submitting = false;

    snapshotPristine(form);

    function isDirty() {
      return formIsDirty(form);
    }

    function currentState() {
      return captureTrackedState(form, mode);
    }

    function pristineState() {
      var state;
      if (mode === 'table') {
        state = { rows: {} };
        trackedFields(form).forEach(function (el) {
          var parsed = parseRowFieldName(el.name || '');
          if (!parsed) return;
          if (!state.rows[parsed.rowId]) state.rows[parsed.rowId] = {};
          state.rows[parsed.rowId][parsed.colKey] = el.getAttribute('data-pristine') || '';
        });
        return state;
      }
      state = {};
      trackedFields(form).forEach(function (el) {
        if (!el.name) return;
        state[el.name] = el.getAttribute('data-pristine') || '';
      });
      return state;
    }

    function persistDraft() {
      refreshDirty(form);
      if (!isDirty()) {
        try {
          localStorage.removeItem(storageKey);
        } catch (e) {
          /* ignore */
        }
        return;
      }
      try {
        localStorage.setItem(storageKey, JSON.stringify(currentState()));
      } catch (e) {
        /* quota or private mode */
      }
    }

    function schedulePersist() {
      if (debounceTimer) window.clearTimeout(debounceTimer);
      debounceTimer = window.setTimeout(persistDraft, DEBOUNCE_MS);
    }

    function clearDraft() {
      try {
        localStorage.removeItem(storageKey);
      } catch (e) {
        /* ignore */
      }
    }

    function restoreDraft() {
      var raw;
      try {
        raw = localStorage.getItem(storageKey);
      } catch (e) {
        return false;
      }
      if (!raw) return false;

      var draft;
      try {
        draft = JSON.parse(raw);
      } catch (e) {
        clearDraft();
        return false;
      }

      if (!draft || statesEqual(draft, pristineState())) {
        clearDraft();
        return false;
      }

      applyFormState(form, draft, mode);
      return true;
    }

    function shouldGuardNavigation() {
      if (submitting || !isDirty()) return false;
      var openDialog = document.querySelector('dialog[open]');
      if (openDialog && openDialog.id === saveModalId) return false;
      return true;
    }

    function navigateAway(href) {
      clearDraft();
      window.location.href = href;
    }

    function openLeaveModal(href) {
      pendingHref = href;
      if (leaveModal && typeof leaveModal.showModal === 'function') {
        leaveModal.showModal();
      } else if (window.confirm(t('leave_modal.description', 'You have unsaved changes.'))) {
        navigateAway(href);
      }
    }

    function bindLeaveModal() {
      if (!leaveModal || leaveModal.dataset.leaveBound) return;
      leaveModal.dataset.leaveBound = '1';

      var stayBtn = leaveModal.querySelector('[data-leave-stay]');
      var discardBtn = leaveModal.querySelector('[data-leave-discard]');
      var saveBtn = leaveModal.querySelector('[data-leave-save]');

      if (stayBtn) {
        stayBtn.addEventListener('click', function () {
          pendingHref = null;
          leaveModal.close();
        });
      }

      if (discardBtn) {
        discardBtn.addEventListener('click', function () {
          var href = pendingHref;
          pendingHref = null;
          leaveModal.close();
          if (href) navigateAway(href);
        });
      }

      if (saveBtn) {
        saveBtn.addEventListener('click', function () {
          pendingHref = null;
          leaveModal.close();
          var saveDialog = document.getElementById(saveModalId);
          if (saveDialog && typeof saveDialog.showModal === 'function') {
            saveDialog.showModal();
            if (window.IsooMarkdownEditor) window.IsooMarkdownEditor.mountVisible(saveDialog);
          }
        });
      }

      leaveModal.addEventListener('close', function () {
        pendingHref = null;
      });
    }

    function onLinkClick(event) {
      if (!shouldGuardNavigation()) return;

      var link = event.target.closest('a[href]');
      if (!link) return;
      if (link.target === '_blank' || link.hasAttribute('download')) return;

      var href = link.getAttribute('href');
      if (!href || href.charAt(0) === '#') return;
      if (link.hasAttribute('data-leave-allowed')) return;

      event.preventDefault();
      event.stopPropagation();
      openLeaveModal(link.href);
    }

    function onFieldEdit(event) {
      var el = event.target;
      if (!el) return;
      if (!el.hasAttribute || !el.hasAttribute('data-draft-track')) {
        el = el.closest ? el.closest('[data-draft-track]') : null;
      }
      if (!el) return;
      var belongs =
        form.contains(el) || (form.id && el.getAttribute('form') === form.id);
      if (!belongs) return;
      updateFieldDirty(el);
      schedulePersist();
    }

    if (restoreDraft()) {
      showToast(t('draft.restored', 'Unsaved draft restored.'));
    }

    form.addEventListener('input', onFieldEdit);
    form.addEventListener('change', onFieldEdit);
    if (form.id) {
      document.querySelectorAll('[data-draft-track][form="' + form.id + '"]').forEach(function (el) {
        el.addEventListener('input', onFieldEdit);
        el.addEventListener('change', onFieldEdit);
      });
    }

    form.addEventListener('submit', function () {
      submitting = true;
      if (debounceTimer) window.clearTimeout(debounceTimer);
      // Keep draft until the next successful page render clears it via pristine match.
    });

    window.addEventListener('beforeunload', function (event) {
      if (submitting || !isDirty()) return;
      event.preventDefault();
      event.returnValue = '';
    });

    document.addEventListener('click', onLinkClick, true);
    bindLeaveModal();
  }

  document.addEventListener('DOMContentLoaded', function () {
    document.querySelectorAll('[data-form-draft]').forEach(bind);
  });
})();
