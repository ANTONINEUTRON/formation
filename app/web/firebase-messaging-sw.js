// Receives pushes while Formation isn't open in a tab (SCORING_PLAN.md
// Phase 4). firebase_messaging registers this file from the site root.
// The config is the public web app config from lib/firebase_options.dart;
// none of it is secret.
importScripts('https://www.gstatic.com/firebasejs/10.13.2/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.13.2/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyBKTO_07nuYNQ15HKEfRbFskwPzxn_s2fI',
  appId: '1:557477536716:web:9adcdf32e00e469c113369',
  messagingSenderId: '557477536716',
  projectId: 'symbians-820b0',
  authDomain: 'symbians-820b0.firebaseapp.com',
  storageBucket: 'symbians-820b0.firebasestorage.app',
});

// FCM shows notification messages itself; this only keeps the handler alive.
firebase.messaging();

// Tapping a push opens (or focuses) the app on its notifications.
self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true }).then((windows) => {
      for (const w of windows) {
        if ('focus' in w) return w.focus();
      }
      return clients.openWindow('/');
    }),
  );
});
