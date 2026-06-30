(function () {
  function dismissToast(toast) {
    toast.style.opacity = '0';
    toast.style.transition = 'opacity 0.3s ease';
    window.setTimeout(function () {
      toast.remove();
    }, 300);
  }

  document.addEventListener('DOMContentLoaded', function () {
    var toast = document.querySelector('[data-toast]');
    if (!toast) return;

    var dismissBtn = toast.querySelector('[data-toast-dismiss]');
    if (dismissBtn) {
      dismissBtn.addEventListener('click', function () {
        dismissToast(toast);
      });
    }

    window.setTimeout(function () {
      dismissToast(toast);
    }, 5000);
  });
})();
