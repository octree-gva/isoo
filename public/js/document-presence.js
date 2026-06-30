(function () {
  function formatNames(editors) {
    if (!editors.length) return '';
    if (editors.length === 1) {
      return I18n.presence.editing_with_one.replace('%{name}', editors[0].name || 'Someone');
    }
    var names = editors.map(function (e) { return e.name || 'Someone'; }).join(', ');
    return I18n.presence.editing_with_many.replace('%{names}', names);
  }

  function initPresence(root) {
    var heartbeatUrl = root.getAttribute('data-heartbeat-url');
    var leaveUrl = root.getAttribute('data-leave-url');
    var messageEl = root.querySelector('[data-presence-message]');
    var pollMs = 5000;
    var timer = null;

    function apply(editors) {
      if (!editors.length) {
        root.classList.add('hidden');
        root.classList.remove('document-presence--active');
        if (messageEl) messageEl.textContent = '';
        return;
      }
      root.classList.remove('hidden');
      root.classList.add('document-presence--active');
      if (messageEl) messageEl.textContent = formatNames(editors);
    }

    function heartbeat() {
      fetch(heartbeatUrl, {
        method: 'POST',
        credentials: 'same-origin',
        headers: { Accept: 'application/json' }
      })
        .then(function (res) {
          if (!res.ok) throw new Error('presence failed');
          return res.json();
        })
        .then(function (data) {
          if (data.poll_interval) pollMs = data.poll_interval * 1000;
          apply(data.editors || []);
          schedule();
        })
        .catch(function () {
          schedule();
        });
    }

    function schedule() {
      if (timer) window.clearTimeout(timer);
      timer = window.setTimeout(heartbeat, pollMs);
    }

    function leave() {
      if (navigator.sendBeacon) {
        navigator.sendBeacon(leaveUrl, '');
      } else {
        fetch(leaveUrl, { method: 'POST', credentials: 'same-origin', keepalive: true });
      }
    }

    heartbeat();
    window.addEventListener('beforeunload', leave);
    document.addEventListener('visibilitychange', function () {
      if (document.visibilityState === 'hidden') leave();
    });
  }

  document.addEventListener('DOMContentLoaded', function () {
    document.querySelectorAll('[data-document-presence]').forEach(initPresence);
  });
})();
