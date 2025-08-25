'use strict';
const MANIFEST = 'flutter-app-manifest';
const TEMP = 'flutter-temp-cache';
const CACHE_NAME = 'flutter-app-cache';

const RESOURCES = {"assets/AssetManifest.bin": "5769d599517202f51684f57f4b5293ca",
"assets/AssetManifest.bin.json": "d38cc03ea8f30df5d11e8881fa7c4b5a",
"assets/AssetManifest.json": "74de046ba3d365b5d0fd364394689e1b",
"assets/assets/MRTvedio/abc.mp4": "13fe14fb08cdb03ded5259dd50af01f6",
"assets/assets/MRTvedio/blue.mp4": "65ce5a94fb7afe7d3c5a0b68035f4253",
"assets/assets/MRTvedio/boy.mp4": "2d4d4b6d25b888cc20252fd149296fed",
"assets/assets/MRTvedio/ccc.mp4": "c120a44dc7dfbeaa6d5521d736c1e971",
"assets/assets/MRTvedio/hotspring.mp4": "3caeea67fb34e0a83abe2fee08f44aa8",
"assets/assets/MRTvedio/market.mp4": "13fe14fb08cdb03ded5259dd50af01f6",
"assets/assets/MRTvedio/mt.mp4": "36ee33c738dd75eddc6574da50034148",
"assets/assets/MRTvedio/night.mp4": "e8c5f242e6d97dcb548ca556169baec6",
"assets/assets/MRTvedio/rain.mp4": "8904928347904d479bfaf7efa246e5d5",
"assets/assets/MRTvedio/run.mp4": "2a79b7c4eacc1251d511aab3e2f2eb8b",
"assets/assets/MRTvedio/sun.mp4": "d9b59c43944dd606f1352c888a45af06",
"assets/assets/MRTvedio/walk.mp4": "f3cb158e346d6f3b0c595c94386598d8",
"assets/assets/MRTvedio/zoo.mp4": "a2f4b02a5fbf7fc41a0ab91730591d57",
"assets/assets/mrt_knowledge/GAME_GUIDE.md": "fd9729b1ab74e59d907b042c1c0df7c3",
"assets/assets/mrt_knowledge/index.html": "30a9ec746486602e01034dce5ae51a57",
"assets/assets/mrt_knowledge/INSTALL_GUIDE.md": "ede32cfb2e450304b6e374ed3d19afe5",
"assets/assets/mrt_knowledge/jamie_take_mrt.png": "1e3a0d2fdbb2f7e7c5d5cb54151ec571",
"assets/assets/mrt_knowledge/main.js": "e84f14bc1fdfdb9223bda3f96613340b",
"assets/assets/mrt_knowledge/mrt_music.mp3": "866a543f8ad59cedfe48478360cefa51",
"assets/assets/mrt_knowledge/README.md": "5db9c781184ddda438f967f3e9fe1cb5",
"assets/assets/mrt_knowledge/SETUP_SUMMARY.md": "a8ee04f079f2cde2b74b2c67f483745e",
"assets/assets/mrt_knowledge/start_game.bat": "0d8e88e0d390913d3742e60bcf3eb6de",
"assets/assets/mrt_knowledge/style.css": "9688deef923d8bf6b4ed7a094030c60f",
"assets/assets/mrt_knowledge/taipei.db": "fd38213c3d0b69cf95d886bee6ea2d4f",
"assets/assets/mrt_knowledge/taipei_metro_quiz.db": "170888fafbdf52beda18bb6b7ec98e41",
"assets/FontManifest.json": "dc3d03800ccca4601324923c0b1d6d57",
"assets/fonts/MaterialIcons-Regular.otf": "1cf9bcf62b9b3220eda97bf05fde5868",
"assets/NOTICES": "6dd86b26716ab2b29550239af578f3f6",
"assets/packages/cupertino_icons/assets/CupertinoIcons.ttf": "33b7d9392238c04c131b6ce224e13711",
"assets/shaders/ink_sparkle.frag": "ecc85a2e95f5e9f53123dcaf8cb9b6ce",
"canvaskit/canvaskit.js": "140ccb7d34d0a55065fbd422b843add6",
"canvaskit/canvaskit.js.symbols": "58832fbed59e00d2190aa295c4d70360",
"canvaskit/canvaskit.wasm": "07b9f5853202304d3b0749d9306573cc",
"canvaskit/chromium/canvaskit.js": "5e27aae346eee469027c80af0751d53d",
"canvaskit/chromium/canvaskit.js.symbols": "193deaca1a1424049326d4a91ad1d88d",
"canvaskit/chromium/canvaskit.wasm": "24c77e750a7fa6d474198905249ff506",
"canvaskit/skwasm.js": "1ef3ea3a0fec4569e5d531da25f34095",
"canvaskit/skwasm.js.symbols": "0088242d10d7e7d6d2649d1fe1bda7c1",
"canvaskit/skwasm.wasm": "264db41426307cfc7fa44b95a7772109",
"canvaskit/skwasm_heavy.js": "413f5b2b2d9345f37de148e2544f584f",
"canvaskit/skwasm_heavy.js.symbols": "3c01ec03b5de6d62c34e17014d1decd3",
"canvaskit/skwasm_heavy.wasm": "8034ad26ba2485dab2fd49bdd786837b",
"favicon.png": "5dcef449791fa27946b3d35ad8803796",
"flutter.js": "888483df48293866f9f41d3d9274a779",
"flutter_bootstrap.js": "f4e5b1fd463aab5fbc8c1cccdbd2a9a2",
"icons/Icon-192.png": "ac9a721a12bbc803b44f645561ecb1e1",
"icons/Icon-512.png": "96e752610906ba2a93c65f8abe1645f1",
"icons/Icon-maskable-192.png": "c457ef57daa1d16f64b27b786ec2ea3c",
"icons/Icon-maskable-512.png": "301a7604d45b3e739efc881eb04896ea",
"index.html": "9cc34a7cb01ed384309e2166a6aa5dfb",
"/": "9cc34a7cb01ed384309e2166a6aa5dfb",
"main.dart.js": "c3f4dd20b2fe1a0b6a72a72cc681657c",
"manifest.json": "5a0edaf796af53d150b9c8ff9948caf1",
"version.json": "15235b5108d6a877ef74fe3317a96bf7"};
// The application shell files that are downloaded before a service worker can
// start.
const CORE = ["main.dart.js",
"index.html",
"flutter_bootstrap.js",
"assets/AssetManifest.bin.json",
"assets/FontManifest.json"];

// During install, the TEMP cache is populated with the application shell files.
self.addEventListener("install", (event) => {
  self.skipWaiting();
  return event.waitUntil(
    caches.open(TEMP).then((cache) => {
      return cache.addAll(
        CORE.map((value) => new Request(value, {'cache': 'reload'})));
    })
  );
});
// During activate, the cache is populated with the temp files downloaded in
// install. If this service worker is upgrading from one with a saved
// MANIFEST, then use this to retain unchanged resource files.
self.addEventListener("activate", function(event) {
  return event.waitUntil(async function() {
    try {
      var contentCache = await caches.open(CACHE_NAME);
      var tempCache = await caches.open(TEMP);
      var manifestCache = await caches.open(MANIFEST);
      var manifest = await manifestCache.match('manifest');
      // When there is no prior manifest, clear the entire cache.
      if (!manifest) {
        await caches.delete(CACHE_NAME);
        contentCache = await caches.open(CACHE_NAME);
        for (var request of await tempCache.keys()) {
          var response = await tempCache.match(request);
          await contentCache.put(request, response);
        }
        await caches.delete(TEMP);
        // Save the manifest to make future upgrades efficient.
        await manifestCache.put('manifest', new Response(JSON.stringify(RESOURCES)));
        // Claim client to enable caching on first launch
        self.clients.claim();
        return;
      }
      var oldManifest = await manifest.json();
      var origin = self.location.origin;
      for (var request of await contentCache.keys()) {
        var key = request.url.substring(origin.length + 1);
        if (key == "") {
          key = "/";
        }
        // If a resource from the old manifest is not in the new cache, or if
        // the MD5 sum has changed, delete it. Otherwise the resource is left
        // in the cache and can be reused by the new service worker.
        if (!RESOURCES[key] || RESOURCES[key] != oldManifest[key]) {
          await contentCache.delete(request);
        }
      }
      // Populate the cache with the app shell TEMP files, potentially overwriting
      // cache files preserved above.
      for (var request of await tempCache.keys()) {
        var response = await tempCache.match(request);
        await contentCache.put(request, response);
      }
      await caches.delete(TEMP);
      // Save the manifest to make future upgrades efficient.
      await manifestCache.put('manifest', new Response(JSON.stringify(RESOURCES)));
      // Claim client to enable caching on first launch
      self.clients.claim();
      return;
    } catch (err) {
      // On an unhandled exception the state of the cache cannot be guaranteed.
      console.error('Failed to upgrade service worker: ' + err);
      await caches.delete(CACHE_NAME);
      await caches.delete(TEMP);
      await caches.delete(MANIFEST);
    }
  }());
});
// The fetch handler redirects requests for RESOURCE files to the service
// worker cache.
self.addEventListener("fetch", (event) => {
  if (event.request.method !== 'GET') {
    return;
  }
  var origin = self.location.origin;
  var key = event.request.url.substring(origin.length + 1);
  // Redirect URLs to the index.html
  if (key.indexOf('?v=') != -1) {
    key = key.split('?v=')[0];
  }
  if (event.request.url == origin || event.request.url.startsWith(origin + '/#') || key == '') {
    key = '/';
  }
  // If the URL is not the RESOURCE list then return to signal that the
  // browser should take over.
  if (!RESOURCES[key]) {
    return;
  }
  // If the URL is the index.html, perform an online-first request.
  if (key == '/') {
    return onlineFirst(event);
  }
  event.respondWith(caches.open(CACHE_NAME)
    .then((cache) =>  {
      return cache.match(event.request).then((response) => {
        // Either respond with the cached resource, or perform a fetch and
        // lazily populate the cache only if the resource was successfully fetched.
        return response || fetch(event.request).then((response) => {
          if (response && Boolean(response.ok)) {
            cache.put(event.request, response.clone());
          }
          return response;
        });
      })
    })
  );
});
self.addEventListener('message', (event) => {
  // SkipWaiting can be used to immediately activate a waiting service worker.
  // This will also require a page refresh triggered by the main worker.
  if (event.data === 'skipWaiting') {
    self.skipWaiting();
    return;
  }
  if (event.data === 'downloadOffline') {
    downloadOffline();
    return;
  }
});
// Download offline will check the RESOURCES for all files not in the cache
// and populate them.
async function downloadOffline() {
  var resources = [];
  var contentCache = await caches.open(CACHE_NAME);
  var currentContent = {};
  for (var request of await contentCache.keys()) {
    var key = request.url.substring(origin.length + 1);
    if (key == "") {
      key = "/";
    }
    currentContent[key] = true;
  }
  for (var resourceKey of Object.keys(RESOURCES)) {
    if (!currentContent[resourceKey]) {
      resources.push(resourceKey);
    }
  }
  return contentCache.addAll(resources);
}
// Attempt to download the resource online before falling back to
// the offline cache.
function onlineFirst(event) {
  return event.respondWith(
    fetch(event.request).then((response) => {
      return caches.open(CACHE_NAME).then((cache) => {
        cache.put(event.request, response.clone());
        return response;
      });
    }).catch((error) => {
      return caches.open(CACHE_NAME).then((cache) => {
        return cache.match(event.request).then((response) => {
          if (response != null) {
            return response;
          }
          throw error;
        });
      });
    })
  );
}
