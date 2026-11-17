importScripts('https://www.gstatic.com/firebasejs/10.14.1/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/10.14.1/firebase-messaging-compat.js');

firebase.initializeApp({
  apiKey: 'AIzaSyDWFHhjAb_uH-5XMnkF__N29WSkYc71-3M',
  appId: '1:583868776785:web:9d7f2b927ded8c1df6d370',
  messagingSenderId: '583868776785',
  projectId: 'i-green-tech',
  storageBucket: 'i-green-tech.firebasestorage.app',
});

const messaging = firebase.messaging();

messaging.onBackgroundMessage((payload) => {
  const title = payload?.notification?.title || payload?.data?.title || 'Igreen Notification';
  const body = payload?.notification?.body || payload?.data?.message || '';
  const route = payload?.data?.route || '/';

  // When payload already contains a notification block, FCM displays it automatically;
  // only show manually for data-only payloads to avoid duplicate notifications.
  if (!payload?.notification) {
    self.registration.showNotification(title, {
      body,
      icon: '/icons/Icon-192.png',
      badge: '/icons/Icon-192.png',
      data: { route },
    });
  }
});

self.addEventListener('notificationclick', (event) => {
  event.notification.close();
  const route = event.notification?.data?.route || event.notification?.data?.FCM_MSG?.data?.route || '/';
  const targetUrl = new URL(route.startsWith('/') ? route : `/${route}`, self.location.origin).href;

  event.waitUntil(
    clients.matchAll({ type: 'window', includeUncontrolled: true }).then((windowClients) => {
      for (const client of windowClients) {
        if (client.url.startsWith(self.location.origin) && 'focus' in client) {
          client.navigate(targetUrl);
          return client.focus();
        }
      }
      if (clients.openWindow) {
        return clients.openWindow(targetUrl);
      }
      return undefined;
    })
  );
});
