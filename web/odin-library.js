// Minimal Odin browser runtime imports used by the gallery.
mergeInto(LibraryManager.library, {
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
