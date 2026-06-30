(function () {
  function todayAtMidnight() {
    var d = new Date();
    d.setHours(0, 0, 0, 0);
    return d;
  }

  function isFutureDate(value) {
    if (!value) return true;
    var picked = new Date(value + 'T00:00:00');
    return picked > todayAtMidnight();
  }

  function validateField(field) {
    if (field.dataset.reviewDate === 'true') {
      var msg = field.getAttribute('data-future-date-message') || 'Choose a future date.';
      if (!isFutureDate(field.value)) {
        field.setCustomValidity(msg);
        return false;
      }
    }
    field.setCustomValidity('');
    if (!field.checkValidity()) return false;
    return true;
  }

  function validateStep(panel) {
    if (!panel) return true;
    if (window.IsooMarkdownEditor) window.IsooMarkdownEditor.syncAll(panel);
    var fields = panel.querySelectorAll('input, textarea, select');
    for (var i = 0; i < fields.length; i++) {
      var field = fields[i];
      if (field.type === 'hidden') continue;
      if (!field.willValidate && !field.dataset.reviewDate) continue;
      if (!validateField(field)) {
        field.reportValidity();
        return false;
      }
    }
    return true;
  }

  function setFieldValue(input, value) {
    if (input.type === 'checkbox') {
      input.checked = ['1', 'true', 'yes', 'on'].includes(String(value).toLowerCase());
    } else if (input.matches('[data-markdown-editor]') && window.IsooMarkdownEditor) {
      window.IsooMarkdownEditor.setValue(input, value);
    } else {
      input.value = value || '';
    }
  }

  function getTextFormField(form, key) {
    if (key === 'document_title') {
      return form.querySelector('[name="document_title"]');
    }
    return form.querySelector('[name="' + key + '"]');
  }

  function syncTextWizardFromForm(dialog) {
    var form = document.getElementById('text_save_form');
    if (!form) return;
    dialog.querySelectorAll('[data-text-wizard-field]').forEach(function (field) {
      var key = field.getAttribute('data-text-wizard-field');
      if (key === 'document_changes' || key === 'significant_change') return;
      var source = getTextFormField(form, key);
      if (!source) return;
      if (source.type === 'checkbox') {
        field.checked = source.checked;
      } else {
        setFieldValue(field, source.value);
      }
    });
  }

  function syncTextWizardToForm(dialog) {
    var form = document.getElementById('text_save_form');
    if (!form) return false;
    if (window.IsooMarkdownEditor) window.IsooMarkdownEditor.syncAll(dialog);
    dialog.querySelectorAll('[data-text-wizard-field]').forEach(function (field) {
      var key = field.getAttribute('data-text-wizard-field');
      var target;
      if (key === 'document_changes') {
        target = document.getElementById('document_changes');
      } else if (key === 'significant_change') {
        target = document.getElementById('significant_change');
      } else {
        target = getTextFormField(form, key);
      }
      if (!target) return;
      if (field.type === 'checkbox') {
        target.checked = field.checked;
      } else {
        setFieldValue(target, field.value);
      }
    });
    form.requestSubmit();
    return true;
  }

  function prefillWizard(dialog, data) {
    dialog.querySelectorAll('[data-row-field]').forEach(function (input) {
      var key = input.getAttribute('data-row-field');
      setFieldValue(input, data[key]);
    });
    var rowId = dialog.querySelector('input[name="row_id"]');
    if (rowId) rowId.value = data._row_id || '';
  }

  function clearWizardFields(dialog) {
    dialog.querySelectorAll('[data-row-field]').forEach(function (input) {
      if (input.type === 'checkbox') {
        var def = input.getAttribute('data-switch-default');
        input.checked = def === '1';
      } else {
        setFieldValue(input, '');
      }
    });
    var rowId = dialog.querySelector('input[name="row_id"]');
    if (rowId) rowId.value = '';
  }

  function findWizardForm(dialog, root, submitBtn) {
    if (submitBtn) {
      var formId = submitBtn.getAttribute('form');
      if (formId) {
        var external = document.getElementById(formId);
        if (external) return external;
      }
    }
    var nested = root.closest('form');
    if (nested) return nested;
    if (!dialog) return null;
    return dialog.querySelector('form:not(.modal-backdrop)');
  }

  function initWizard(root) {
    var steps = root.querySelectorAll('[data-wizard-step]');
    var total = steps.length;
    var titleEl = root.querySelector('[data-wizard-title]');
    var titleBase = titleEl ? (titleEl.dataset.wizardTitleBase || titleEl.textContent.trim()) : '';
    var prevBtn = root.querySelector('[data-wizard-prev]');
    var nextBtn = root.querySelector('[data-wizard-next]');
    var submitBtn = root.querySelector('[data-wizard-submit]');
    var finishBtn = root.querySelector('[data-text-wizard-finish]');
    var isTextWizard = root.hasAttribute('data-text-wizard');
    var dialog = root.closest('dialog');
    var form = isTextWizard ? null : findWizardForm(dialog, root, submitBtn);
    var step = 1;

    function currentPanel() {
      return root.querySelector('[data-wizard-step="' + step + '"]');
    }

    function focusStep(targetStep) {
      var focus = root.querySelector(
        '[data-wizard-step="' + targetStep + '"] input:not([type="hidden"]), ' +
        '[data-wizard-step="' + targetStep + '"] textarea, ' +
        '[data-wizard-step="' + targetStep + '"] select'
      );
      if (!focus) return;
      if (focus.matches('[data-markdown-editor]') && window.IsooMarkdownEditor &&
          window.IsooMarkdownEditor.focusEditor(focus)) {
        return;
      }
      focus.focus();
    }

    function ensureProgressDots() {
      var progressEl = root.querySelector('[data-wizard-progress]');
      if (!progressEl || progressEl.dataset.wizardProgressBuilt) return;
      progressEl.dataset.wizardProgressBuilt = 'true';
      progressEl.setAttribute('role', 'list');
      for (var i = 1; i <= total; i++) {
        var dot = document.createElement('span');
        dot.className = 'wizard-progress__dot wizard-progress__dot--upcoming';
        dot.setAttribute('data-wizard-dot', String(i));
        dot.setAttribute('role', 'listitem');
        progressEl.appendChild(dot);
      }
    }

    function updateProgress() {
      var progressEl = root.querySelector('[data-wizard-progress]');
      if (!progressEl) return;
      progressEl.setAttribute('aria-label', 'Step ' + step + ' of ' + total);
      progressEl.querySelectorAll('[data-wizard-dot]').forEach(function (dot) {
        var n = parseInt(dot.getAttribute('data-wizard-dot'), 10);
        dot.className = 'wizard-progress__dot';
        dot.removeAttribute('aria-current');
        if (n < step) {
          dot.classList.add('wizard-progress__dot--complete');
          dot.setAttribute('aria-label', 'Step ' + n + ' complete');
        } else if (n === step) {
          dot.classList.add('wizard-progress__dot--active');
          dot.setAttribute('aria-current', 'step');
          dot.setAttribute('aria-label', 'Step ' + n + ' current');
        } else {
          dot.classList.add('wizard-progress__dot--upcoming');
          dot.setAttribute('aria-label', 'Step ' + n);
        }
      });
    }

    function update() {
      steps.forEach(function (el) {
        var n = parseInt(el.getAttribute('data-wizard-step'), 10);
        el.hidden = n !== step;
      });
      if (titleEl) {
        titleEl.textContent = titleBase;
      }
      updateProgress();
      if (prevBtn) prevBtn.hidden = step === 1;
      if (nextBtn) nextBtn.hidden = step === total;
      if (submitBtn) submitBtn.hidden = step !== total;
      if (finishBtn) finishBtn.hidden = step !== total;
      if (window.IsooMarkdownEditor) {
        window.IsooMarkdownEditor.mountVisible(currentPanel());
      }
    }

    function goNext() {
      var panel = currentPanel();
      if (!validateStep(panel)) return false;
      if (step >= total) return false;
      step += 1;
      update();
      focusStep(step);
      return true;
    }

    function validateAllSteps() {
      for (var s = 1; s <= total; s++) {
        var panel = root.querySelector('[data-wizard-step="' + s + '"]');
        if (!validateStep(panel)) return false;
      }
      return true;
    }

    function submitForm() {
      if (!validateAllSteps()) return;
      if (isTextWizard) {
        if (syncTextWizardToForm(dialog)) dialog.close();
        return;
      }
      if (form) form.requestSubmit();
    }

    function reset() {
      step = 1;
      update();
    }

    if (nextBtn) {
      nextBtn.addEventListener('click', goNext);
    }

    if (prevBtn) {
      prevBtn.addEventListener('click', function () {
        if (step > 1) {
          step -= 1;
          update();
          focusStep(step);
        }
      });
    }

    if (submitBtn) {
      submitBtn.addEventListener('click', submitForm);
    }

    if (finishBtn) {
      finishBtn.addEventListener('click', submitForm);
    }

    root.addEventListener('keydown', function (event) {
      if (event.key !== 'Enter' || event.isComposing) return;
      var target = event.target;
      if (!target || !root.contains(target)) return;
      if (target.tagName === 'TEXTAREA') return;
      if (target.closest && target.closest('.markdown-editor')) return;
      if (target.tagName === 'BUTTON') return;
      if (target.type === 'checkbox' || target.type === 'radio') return;

      event.preventDefault();
      if (step < total) {
        goNext();
      } else {
        submitForm();
      }
    });

    root.querySelectorAll('[data-review-date]').forEach(function (input) {
      input.addEventListener('input', function () {
        input.setCustomValidity('');
      });
    });

    if (dialog) {
      dialog.addEventListener('close', reset);
    }

    if (form) {
      form.addEventListener('submit', function (event) {
        if (dialog && !dialog.open) {
          event.preventDefault();
          return;
        }
        if (!validateAllSteps()) {
          event.preventDefault();
          return;
        }
        if (step < total) {
          event.preventDefault();
          goNext();
        }
      });
    }

    root.resetWizard = reset;
    ensureProgressDots();
    update();
  }

  function openPlainDialog(id) {
    var dialog = document.getElementById(id);
    if (!dialog) return;
    dialog.showModal();
  }

  function openDialog(id, options) {
    var dialog = document.getElementById(id);
    if (!dialog) return;
    var wizard = dialog.querySelector('[data-modal-wizard]');
    if (!wizard) {
      openPlainDialog(id);
      return;
    }
    if (id === 'text_wizard_modal') {
      syncTextWizardFromForm(dialog);
    } else if (options && options.prefill) {
      prefillWizard(dialog, options.prefill);
    } else if (dialog.querySelector('[data-row-field]')) {
      clearWizardFields(dialog);
    }
    if (wizard.resetWizard) wizard.resetWizard();
    dialog.showModal();
    if (window.IsooMarkdownEditor) {
      window.IsooMarkdownEditor.mountVisible(dialog);
    }
  }

  document.addEventListener('DOMContentLoaded', function () {
    document.querySelectorAll('[data-modal-wizard]').forEach(initWizard);

    document.querySelectorAll('[data-dialog-open]').forEach(function (btn) {
      btn.addEventListener('click', function () {
        openPlainDialog(btn.getAttribute('data-dialog-open'));
      });
    });

    document.querySelectorAll('[data-wizard-open]').forEach(function (btn) {
      btn.addEventListener('click', function () {
        var prefillRaw = btn.getAttribute('data-wizard-prefill');
        var options = {};
        if (prefillRaw) {
          try {
            options.prefill = JSON.parse(prefillRaw);
          } catch (e) {
            options.prefill = null;
          }
        }
        openDialog(btn.getAttribute('data-wizard-open'), options);
      });
    });

    document.querySelectorAll('[data-delete-row-open]').forEach(function (btn) {
      btn.addEventListener('click', function () {
        var dialogId = btn.getAttribute('data-delete-row-open');
        var dialog = document.getElementById(dialogId);
        if (!dialog) return;
        var form = dialog.querySelector('[data-delete-row-form]');
        if (!form) return;
        var rowIdInput = form.querySelector('input[name="row_id"]');
        if (rowIdInput) {
          rowIdInput.value = btn.getAttribute('data-delete-row-id') || '';
        }
        dialog.showModal();
      });
    });

    var params = new URLSearchParams(window.location.search);
    if (params.get('wizard') === '1') {
      if (document.getElementById('text_wizard_modal')) {
        openDialog('text_wizard_modal');
      } else if (document.getElementById('new_row_modal')) {
        openDialog('new_row_modal');
      }
    }

    var rowShow = document.querySelector('[data-table-row-show]');
    if (rowShow && params.get('edit') === '1') {
      var prefillRaw = rowShow.getAttribute('data-row-prefill');
      if (prefillRaw) {
        try {
          openDialog('edit_row_modal', { prefill: JSON.parse(prefillRaw) });
        } catch (e) {
          /* ignore invalid prefill */
        }
      }
    }
  });
})();
