/* liblzma: the SDK has only the stub, no lzma.h, so the few declarations
   that this test needs are written here (the API of xz 5.0, src/liblzma/api). */
#include <stdint.h>
#include <stdio.h>
#include <string.h>

typedef enum { LZMA_OK = 0 } lzma_ret;
#define LZMA_CHECK_CRC64 4
extern lzma_ret lzma_easy_buffer_encode(uint32_t preset, int check, const void *allocator, const uint8_t *in,
                                        size_t in_size, uint8_t *out, size_t *out_pos, size_t out_size);
extern lzma_ret lzma_stream_buffer_decode(uint64_t *memlimit, uint32_t flags, const void *allocator,
                                          const uint8_t *in, size_t *in_pos, size_t in_size,
                                          uint8_t *out, size_t *out_pos, size_t out_size);
extern uint32_t lzma_crc32(const uint8_t *buf, size_t size, uint32_t crc);
extern const char *lzma_version_string(void);

int main(void) {
  static const char text[] = "liblzma round trip liblzma round trip liblzma round trip";
  uint8_t xz[512], back[sizeof text];
  size_t xz_len = 0, in_pos = 0, back_pos = 0;
  uint64_t memlimit = UINT64_MAX;
  if (lzma_easy_buffer_encode(6, LZMA_CHECK_CRC64, NULL, (const uint8_t *)text, sizeof text,
                              xz, &xz_len, sizeof xz) != LZMA_OK) return 1;
  if (lzma_stream_buffer_decode(&memlimit, 0, NULL, xz, &in_pos, xz_len, back, &back_pos, sizeof back) != LZMA_OK)
    return 2;
  if (back_pos != sizeof text || memcmp(back, text, sizeof text) != 0) return 3;
  printf("liblzma %s: %zu bytes -> %zu bytes -> %zu bytes, crc32=%08x\n", lzma_version_string(),
         sizeof text, xz_len, back_pos, (unsigned)lzma_crc32((const uint8_t *)text, sizeof text, 0));
  return 0;
}
