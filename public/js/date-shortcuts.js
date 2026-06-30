(function () {
  function formatDate(date) {
    return date.toISOString().slice(0, 10);
  }

  function applyShortcut(shortcut) {
    var date = new Date();
    if (shortcut === '3months') {
      date.setMonth(date.getMonth() + 3);
    } else if (shortcut === '6months') {
      date.setMonth(date.getMonth() + 6);
    } else if (shortcut === '1year') {
      date.setFullYear(date.getFullYear() + 1);
    }
    return formatDate(date);
  }

  document.addEventListener('click', function (event) {
    var button = event.target.closest('[data-date-shortcut]');
    if (!button) return;

    var targetId = button.getAttribute('data-date-target');
    var input = targetId ? document.getElementById(targetId) : button.closest('[data-wizard-step]').querySelector('input[type="date"]');
    if (!input) return;

    var shortcut = button.getAttribute('data-date-shortcut');
    input.value = applyShortcut(shortcut);
    input.dispatchEvent(new Event('input', { bubbles: true }));
  });
})();
