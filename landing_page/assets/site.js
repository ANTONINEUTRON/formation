/* Shared by every page on the landing site.
 *
 * Every outside link lives in SITE below, once. A page marks where the shared
 * pieces go and this fills them in:
 *
 *   <header data-site="header"></header>   top bar
 *   <footer data-site="footer"></footer>   footer, legal links and disclaimer
 *   <a data-link="apk">…</a>               any link in SITE, by name
 *   <a data-pick>…</a>                     opens the get-the-app chooser
 *
 * Load it at the end of <body>. To ship a new APK, change SITE.apk only.
 */
(function () {
  var SITE = {
    apk: 'https://firebasestorage.googleapis.com/v0/b/formation-cbf24.firebasestorage.app/o/formation_v0.5.apk?alt=media&token=c6f8536e-cca3-4dc8-8232-dbe3acf11093',
    web: 'https://app.formation.titalabs.xyz',
    x: 'https://x.com/formation_sol',
    home: '/',
    terms: '/terms',
    privacy: '/privacy',
    guide: '/how-to-play',
  };

  var NAV = [
    ['How it works', '/#how'],
    ['Features', '/#features'],
    ['Rules', '/how-to-play'],
  ];

  var X_ICON =
    '<svg width="14" height="14" viewBox="0 0 24 24" fill="currentColor" aria-hidden="true"><path d="M18.244 2.25h3.308l-7.227 8.26 8.502 11.24H16.17l-5.214-6.817L4.99 21.75H1.68l7.73-8.835L1.254 2.25H8.08l4.713 6.231zm-1.161 17.52h1.833L7.084 4.126H5.117z"/></svg>';
  var PHONE_ICON =
    '<svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><rect x="5" y="2" width="14" height="20" rx="2.5"/><path d="M11 18h2"/></svg>';
  var GLOBE_ICON =
    '<svg width="22" height="22" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.8" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><circle cx="12" cy="12" r="9.5"/><path d="M2.5 12h19M12 2.5c2.6 2.6 2.6 16.4 0 19M12 2.5c-2.6 2.6-2.6 16.4 0 19"/></svg>';

  function header() {
    return (
      '<div class="wrap nav__in">' +
        '<a class="brand" href="' + SITE.home + '">' +
          '<img class="brand__logo" src="/formation_logo.png" alt="Formation logo" width="28" height="28">Formation' +
        '</a>' +
        '<nav class="nav__links">' +
          NAV.map(function (l) { return '<a href="' + l[1] + '">' + l[0] + '</a>'; }).join('') +
          '<a class="btn btn--go" data-link="apk" data-pick>Start</a>' +
        '</nav>' +
      '</div>'
    );
  }

  function footer() {
    return (
      '<div class="wrap">' +
        '<div class="foot__in">' +
          '<span class="foot__t">© ' + new Date().getFullYear() + ' Formation</span>' +
          '<nav class="foot__l">' +
            '<a data-link="apk">Android app</a>' +
            '<a data-link="web">Web app</a>' +
            '<a data-link="guide">How to play</a>' +
            '<a data-link="terms">Terms</a>' +
            '<a data-link="privacy">Privacy</a>' +
            '<a data-link="x" aria-label="Formation on X">' + X_ICON + 'X</a>' +
          '</nav>' +
        '</div>' +
        '<p class="rs">' +
          'Formation works with tokenized US stocks and ETFs (xStocks) held in your Solana wallet. ' +
          'Formation is a game of skill. There is no prize pool, no entry fee and no pooled funds; ' +
          'winnings are standing on a leaderboard, not money. Formation is not a broker, dealer or ' +
          'investment adviser, takes no custody of assets, and does not trade on anyone\'s behalf. ' +
          'Nothing here is investment advice, and the value of any holding can fall.' +
        '</p>' +
      '</div>'
    );
  }

  function chooser() {
    return (
      '<div class="pick__in">' +
        '<h2 class="pick__h" id="pick-h">Two ways in</h2>' +
        '<p class="pick__p">Both play the same game against the same leaderboard, with the same stocks in your own wallet.</p>' +
        '<div class="pick__opts">' +
          '<a class="pick__opt" data-link="apk">' + PHONE_ICON +
            '<span><span class="pick__t">Download the Android app</span>' +
            '<span class="pick__s">Signs with your phone\'s wallet. Built for Seeker.</span></span>' +
          '</a>' +
          '<a class="pick__opt" data-link="web">' + GLOBE_ICON +
            '<span><span class="pick__t">Play in your browser</span>' +
            '<span class="pick__s">Nothing to install. Connect Phantom, Solflare or Backpack.</span></span>' +
          '</a>' +
        '</div>' +
        '<button class="pick__x" type="button" data-pick-close>Not now</button>' +
      '</div>'
    );
  }

  function each(selector, fn) {
    Array.prototype.forEach.call(document.querySelectorAll(selector), fn);
  }

  // 1. The shared pieces.
  each('[data-site="header"]', function (el) {
    el.classList.add('nav');
    el.innerHTML = header();
  });
  each('[data-site="footer"]', function (el) {
    el.classList.add('foot');
    el.innerHTML = footer();
  });

  // 2. The chooser, only on pages that offer it.
  var pick = null;
  if (document.querySelector('[data-pick]')) {
    pick = document.createElement('dialog');
    pick.className = 'pick';
    pick.setAttribute('aria-labelledby', 'pick-h');
    pick.innerHTML = chooser();
    document.body.appendChild(pick);
  }

  // 3. Links, after everything above has added its own.
  each('[data-link]', function (a) {
    var url = SITE[a.getAttribute('data-link')];
    if (url) a.setAttribute('href', url);
  });

  // 4. "Start" opens the chooser. Its href is still the APK, so where
  //    <dialog> isn't supported the button just skips the choice.
  if (!pick || typeof pick.showModal !== 'function') return;

  each('[data-pick]', function (trigger) {
    trigger.addEventListener('click', function (event) {
      event.preventDefault();
      pick.showModal();
    });
  });

  pick.querySelector('[data-pick-close]').addEventListener('click', function () {
    pick.close();
  });

  // Clicking the backdrop closes it. The backdrop is the dialog element
  // itself; anything inside .pick__in is a real target and must not.
  pick.addEventListener('click', function (event) {
    if (event.target === pick) pick.close();
  });
})();
