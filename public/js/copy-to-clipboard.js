(function () {
  function copyText(text) {
    if (navigator.clipboard && window.isSecureContext) {
      return navigator.clipboard.writeText(text);
    }

    return new Promise(function (resolve, reject) {
      var textarea = document.createElement('textarea');
      textarea.value = text;
      textarea.setAttribute('readonly', '');
      textarea.style.position = 'absolute';
      textarea.style.left = '-9999px';
      document.body.appendChild(textarea);
      textarea.select();
      try {
        document.execCommand('copy');
        resolve();
      } catch (error) {
        reject(error);
      } finally {
        document.body.removeChild(textarea);
      }
    });
  }

  function toastMessage(button) {
    return button.getAttribute('data-copy-toast') || 'Copied to clipboard.';
  }

  function announce(button, message) {
    var status = document.getElementById(button.getAttribute('data-copy-status'));
    if (status) {
      status.textContent = message;
      return;
    }

    var toast = document.createElement('div');
    toast.className = 'toast toast-top toast-end z-50 pointer-events-none';
    toast.setAttribute('role', 'status');
    toast.setAttribute('aria-live', 'polite');
    toast.innerHTML =
      '<div class="alert alert-success shadow-lg max-w-md pointer-events-auto">' +
      '<i class="ri-checkbox-circle-line text-xl shrink-0" aria-hidden="true"></i>' +
      '<span class="flex-1 text-base"></span>' +
      '</div>';
    toast.querySelector('span').textContent = message;
    document.body.appendChild(toast);
    window.setTimeout(function () {
      toast.remove();
    }, 2500);
  }

  document.addEventListener('click', function (event) {
    var button = event.target.closest('[data-copy]');
    if (!button) return;

    event.preventDefault();
    var text = button.getAttribute('data-copy');
    if (!text) return;

    copyText(text).then(function () {
      announce(button, toastMessage(button));
    });
  });
})();
