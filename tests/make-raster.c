/* SPDX-License-Identifier: MIT
 * Synthetic CUPS raster fixtures. They contain no personal or vendor data.
 */
#define _DARWIN_C_SOURCE
#include <cups/raster.h>
#include <fcntl.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

int main(int argc, char **argv) {
    if (argc != 5) return 1;
    int fd = open(argv[1], O_CREAT | O_TRUNC | O_WRONLY, 0600);
    if (fd < 0) return 1;
    cups_raster_t *raster = cupsRasterOpen(fd, CUPS_RASTER_WRITE);
    if (!raster) { close(fd); return 1; }
    cups_page_header2_t h;
    memset(&h, 0, sizeof(h));
    h.cupsWidth = 161; h.cupsHeight = 81;
    h.HWResolution[0] = h.HWResolution[1] = 203;
    h.cupsBitsPerColor = h.cupsBitsPerPixel = 1;
    h.cupsColorSpace = CUPS_CSPACE_W;
    h.cupsColorOrder = CUPS_ORDER_CHUNKED;
    h.cupsNumColors = 1;
    h.NumCopies = (unsigned)atoi(argv[3]);
    const char *format = argv[2];
    if (!strcmp(format, "black1")) h.cupsColorSpace = CUPS_CSPACE_K;
    if (!strcmp(format, "gray8") || !strcmp(format, "black8")) h.cupsBitsPerColor = h.cupsBitsPerPixel = 8;
    if (!strcmp(format, "black8")) h.cupsColorSpace = CUPS_CSPACE_K;
    if (!strcmp(format, "rgb8")) { h.cupsBitsPerColor = 8; h.cupsBitsPerPixel = 24; h.cupsColorSpace = CUPS_CSPACE_SRGB; h.cupsNumColors = 3; }
    if (!strcmp(format, "wide")) h.cupsWidth = 610;
    if (!strcmp(format, "tall")) h.cupsHeight = 7994;
    if (!strcmp(format, "dpi")) h.HWResolution[0] = h.HWResolution[1] = 300;
    if (!strcmp(format, "planar")) h.cupsColorOrder = CUPS_ORDER_PLANAR;
    if (!strcmp(format, "rgba")) { h.cupsBitsPerColor = 8; h.cupsBitsPerPixel = 32; h.cupsColorSpace = CUPS_CSPACE_RGBA; h.cupsNumColors = 4; }
    h.cupsBytesPerLine = (h.cupsWidth * h.cupsBitsPerPixel + 7) / 8 + (h.cupsNumColors == 3 ? 6 : 4); /* explicit padding */
    h.cupsPageSize[0] = (float)h.cupsWidth * 72 / 203;
    h.cupsPageSize[1] = (float)h.cupsHeight * 72 / 203;
    h.PageSize[0] = (unsigned)h.cupsPageSize[0]; h.PageSize[1] = (unsigned)h.cupsPageSize[1];
    unsigned char *row = malloc(h.cupsBytesPerLine);
    if (!row) return 1;
    int result = 0;
    for (int page = 0; page < atoi(argv[4]); page++) {
        if (!cupsRasterWriteHeader2(raster, &h)) { result = 1; break; }
        for (unsigned y = 0; y < h.cupsHeight; y++) {
            int black_space = h.cupsColorSpace == CUPS_CSPACE_K;
            memset(row, black_space ? 0 : 255, h.cupsBytesPerLine);
            for (unsigned x = 0; x < h.cupsWidth; x++) {
                int black = y % 2 == 0 && (x == 0 || x == 7 || x == 8 || x == h.cupsWidth - 1);
                if (!black) continue;
                if (h.cupsBitsPerPixel == 1) {
                    if (black_space) row[x / 8] |= (unsigned char)(0x80u >> (x % 8));
                    else row[x / 8] &= (unsigned char)~(0x80u >> (x % 8));
                } else {
                    unsigned channels = h.cupsBitsPerPixel / 8;
                    for (unsigned channel = 0; channel < channels; channel++) row[x * channels + channel] = black_space ? 255 : 0;
                }
            }
            if (cupsRasterWritePixels(raster, row, h.cupsBytesPerLine) != h.cupsBytesPerLine) { result = 1; break; }
        }
    }
    free(row); cupsRasterClose(raster); close(fd);
    return result;
}
