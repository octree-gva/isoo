(function () {
  var config = window.IsooSessionIdle || {};
  var timeoutMs = Number(config.timeoutMs);
  var logoutUrl = config.logoutUrl || '/auth/logout';

  if (!timeoutMs || timeoutMs <= 0) return;

  var timer;

  function logout() {
    window.location.href = logoutUrl;
  }

  function resetTimer() {
    clearTimeout(timer);
    timer = setTimeout(logout, timeoutMs);
  }

  ['mousemove', 'mousedown', 'keydown', 'click', 'scroll', 'touchstart'].forEach(function (eventName) {
    document.addEventListener(eventName, resetTimer, { passive: true });
  });

  document.addEventListener('visibilitychange', function () {
    if (!document.hidden) resetTimer();
  });

  resetTimer();
})();
