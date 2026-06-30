(function () {
  function positionMenu(actions) {
    var menu = actions.querySelector('[data-table-fullscreen-menu]');
    var button = actions.querySelector('button');
    if (!menu || !button) return;

    menu.style.position = 'fixed';
    menu.style.minWidth = '11rem';
    menu.style.zIndex = '100';

    var rect = button.getBoundingClientRect();
    var menuWidth = menu.offsetWidth || 208;
    var left = rect.right - menuWidth;
    var top = rect.bottom + 4;
    var maxTop = window.innerHeight - menu.offsetHeight - 8;

    if (top > maxTop) {
      top = Math.max(8, rect.top - menu.offsetHeight - 4);
    }
    if (left < 8) left = 8;
    if (left + menuWidth > window.innerWidth - 8) {
      left = window.innerWidth - menuWidth - 8;
    }

    menu.style.left = left + 'px';
    menu.style.top = top + 'px';
  }

  function resetMenu(menu) {
    menu.style.position = '';
    menu.style.left = '';
    menu.style.top = '';
    menu.style.minWidth = '';
    menu.style.zIndex = '';
  }

  function bindActions(actions) {
    if (actions.dataset.fullscreenActionsBound) return;
    actions.dataset.fullscreenActionsBound = 'true';

    var menu = actions.querySelector('[data-table-fullscreen-menu]');
    if (!menu) return;

    actions.addEventListener('focusin', function () {
      requestAnimationFrame(function () {
        positionMenu(actions);
      });
    });

    actions.addEventListener('focusout', function (event) {
      if (actions.contains(event.relatedTarget)) return;
      resetMenu(menu);
    });
  }

  function init() {
    document.querySelectorAll('[data-table-fullscreen-actions]').forEach(bindActions);
    window.addEventListener('resize', function () {
      document.querySelectorAll('[data-table-fullscreen-actions]').forEach(function (actions) {
        if (actions.contains(document.activeElement)) {
          positionMenu(actions);
        }
      });
    });
    document.querySelectorAll('.table-fullscreen-scroll').forEach(function (scroll) {
      scroll.addEventListener('scroll', function () {
        document.querySelectorAll('[data-table-fullscreen-actions]').forEach(function (actions) {
          if (actions.contains(document.activeElement)) {
            positionMenu(actions);
          }
        });
      }, { passive: true });
    });
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }
})();
