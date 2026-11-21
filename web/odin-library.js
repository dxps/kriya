// Minimal Odin browser runtime imports used by the gallery.
mergeInto(LibraryManager.library, {
  kriya_path_matches__deps: ['$UTF8ToString'],
  kriya_path_matches: function(ptr) {
    return location.pathname === UTF8ToString(ptr);
  },
  kriya_navigate__deps: ['$UTF8ToString'],
  kriya_navigate: function(ptr) {
    const path = UTF8ToString(ptr);
    if (location.pathname !== path) history.pushState(null, '', path);
  },
  // Payloads are short, fixed-length, plain-ASCII flag strings (one char
  // per sidebar group), so this writes/reads raw char codes directly
  // instead of pulling in the UTF8 encode/decode helpers. kriya_storage_get
  // only accepts a stored value whose length matches 'cap' exactly —
  // anything else (missing key, or a stale value from a previous group
  // count) reports as absent so the caller falls back to its default.
  kriya_storage_get__deps: ['$UTF8ToString'],
  kriya_storage_get: function(keyPtr, outPtr, cap) {
    let value;
    try { value = localStorage.getItem(UTF8ToString(keyPtr)); } catch (e) { value = null; }
    if (value == null || value.length !== cap) return 0;
    for (let i = 0; i < value.length; i++) HEAPU8[outPtr + i] = value.charCodeAt(i);
    return value.length;
  },
  kriya_storage_set__deps: ['$UTF8ToString'],
  kriya_storage_set: function(keyPtr, valuePtr) {
    try { localStorage.setItem(UTF8ToString(keyPtr), UTF8ToString(valuePtr)); } catch (e) {}
  },
  write: function(fd, ptr, len) {
    const text = new TextDecoder().decode(HEAPU8.subarray(ptr, ptr + len));
    (fd === 2 ? console.error : console.log)(text);
    return len;
  },
  rand_bytes: function(ptr, len) {
    for (let offset = 0; offset < len; offset += 65536)
      crypto.getRandomValues(HEAPU8.subarray(ptr + offset, ptr + Math.min(len, offset + 65536)));
  }
});
