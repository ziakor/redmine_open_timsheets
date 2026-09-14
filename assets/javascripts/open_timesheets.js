(function () {
  'use strict';

  function insertCalendarTab() {
    var data = document.getElementById('ots-calendar-tab-data');
    if (!data) { return; }

    var tabs = document.querySelector('#content .tabs ul');
    if (!tabs || tabs.querySelector('.ots-calendar-tab')) { return; }

    var item = document.createElement('li');
    item.className = 'ots-calendar-tab';

    var link = document.createElement('a');
    link.href = data.getAttribute('data-url');
    link.textContent = data.getAttribute('data-label');

    item.appendChild(link);
    tabs.appendChild(item);
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', insertCalendarTab);
  } else {
    insertCalendarTab();
  }
})();
