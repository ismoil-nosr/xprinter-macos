/* SPDX-License-Identifier: MIT
 * Copyright (c) 2026 Ismoil Nosr
 * CUPS raster -> TSPL. No vendor binaries, network access or shell commands.
 */
#define _DARWIN_C_SOURCE
#include <cups/cups.h>
#include <cups/ppd.h>
#include <cups/raster.h>
#include <errno.h>
#include <fcntl.h>
#include <limits.h>
#include <math.h>
#include <signal.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

enum { MAX_WIDTH = 609, MAX_HEIGHT = 7993, MAX_COPIES = 100 };
static volatile sig_atomic_t cancelled;

typedef struct {
    int fd;
    size_t bytes;
    int failed;
} Input;

typedef struct {
    int gap, darkness, speed, threshold, job_copies;
    const char *stock;
} Settings;

static void cancel_job(int signal_number) {
    (void)signal_number;
    cancelled = 1;
}

static ssize_t read_input(void *context, unsigned char *buffer, size_t length) {
    Input *input = context;
    ssize_t result;
    do { result = read(input->fd, buffer, length); }
    while (result < 0 && errno == EINTR && !cancelled);
    if (result < 0) input->failed = 1;
    if (result > 0) input->bytes += (size_t)result;
    return result;
}

static int number(const char *value, int minimum, int maximum, int *out) {
    if (!value || !*value) return 0;
    char *end = NULL;
    errno = 0;
    long parsed = strtol(value, &end, 10);
    if (errno || *end || parsed < minimum || parsed > maximum) return 0;
    *out = (int)parsed;
    return 1;
}

static const char *option(ppd_file_t *ppd, int count, cups_option_t *options,
                          const char *key, const char *fallback) {
    const char *value = cupsGetOption(key, count, options);
    if (value) return value;
    ppd_choice_t *choice = ppd ? ppdFindMarkedChoice(ppd, key) : NULL;
    return choice ? choice->choice : fallback;
}

static int settings(int argc, char **argv, Settings *out) {
    int count = 0, result = 0;
    cups_option_t *options = NULL;
    ppd_file_t *ppd = NULL;
    const char *path = getenv("PPD");
    if (path && *path) {
        ppd = ppdOpenFile(path);
        if (!ppd) { fputs("ERROR: Cannot read the printer profile. Reinstall the driver.\n", stderr); return 0; }
        ppdMarkDefaults(ppd);
    }
    count = cupsParseOptions(argv[5], 0, &options);
    if (!number(argv[4], 1, MAX_COPIES, &out->job_copies) ||
        !number(option(ppd, count, options, "GapsHeight", "2"), 0, 10, &out->gap) ||
        !number(option(ppd, count, options, "Darkness", "7"), 0, 15, &out->darkness) ||
        !number(option(ppd, count, options, "PrintSpeed", "3"), 2, 4, &out->speed) ||
        !number(option(ppd, count, options, "Threshold", "128"), 1, 254, &out->threshold)) {
        fputs("ERROR: Invalid copies, gap, darkness, speed or threshold setting.\n", stderr);
        goto done;
    }
    const char *stock = option(ppd, count, options, "PaperType", "LabelGaps");
    if (!strcmp(stock, "LabelGaps")) out->stock = "GAP";
    else if (!strcmp(stock, "LabelMark")) out->stock = "BLINE";
    else if (!strcmp(stock, "Continue")) { out->stock = "GAP"; out->gap = 0; }
    else { fputs("ERROR: Unsupported paper type.\n", stderr); goto done; }
    if (strcmp(stock, "Continue") && out->gap == 0) {
        fputs("ERROR: Gap/mark labels need a positive gap. Choose continuous stock for a roll without gaps.\n", stderr);
        goto done;
    }
    if (strcmp(option(ppd, count, options, "MediaMethod", "Direct"), "Direct")) {
        fputs("ERROR: XP-330B requires direct thermal media.\n", stderr);
        goto done;
    }
    result = 1;
done:
    cupsFreeOptions(count, options);
    if (ppd) ppdClose(ppd);
    (void)argc;
    return result;
}

static int valid_header(const cups_page_header2_t *h) {
    if (!h->cupsWidth || !h->cupsHeight || h->cupsWidth > MAX_WIDTH ||
        h->cupsHeight > MAX_HEIGHT || h->HWResolution[0] != 203 ||
        h->HWResolution[1] != 203 || h->cupsColorOrder != CUPS_ORDER_CHUNKED ||
        h->Duplex || h->NumCopies > MAX_COPIES) return 0;
    unsigned bits = h->cupsBitsPerPixel;
    int gray = h->cupsColorSpace == CUPS_CSPACE_W || h->cupsColorSpace == CUPS_CSPACE_SW ||
               h->cupsColorSpace == CUPS_CSPACE_K;
    int rgb = h->cupsColorSpace == CUPS_CSPACE_RGB || h->cupsColorSpace == CUPS_CSPACE_SRGB;
    if (!(gray && ((bits == 1 && h->cupsBitsPerColor == 1) ||
                   (bits == 8 && h->cupsBitsPerColor == 8))) &&
        !(rgb && bits == 24 && h->cupsBitsPerColor == 8)) return 0;
    unsigned minimum = (h->cupsWidth * bits + 7) / 8;
    return h->cupsBytesPerLine >= minimum && h->cupsBytesPerLine <= 4096;
}

static int black_pixel(const unsigned char *row, unsigned x,
                       const cups_page_header2_t *h, int threshold) {
    if (h->cupsBitsPerPixel == 1) {
        int bit = (row[x / 8] & (0x80u >> (x % 8))) != 0;
        return h->cupsColorSpace == CUPS_CSPACE_K ? bit : !bit;
    }
    if (h->cupsBitsPerPixel == 8)
        return h->cupsColorSpace == CUPS_CSPACE_K ? row[x] > 255 - threshold : row[x] < threshold;
    const unsigned char *pixel = row + x * 3;
    unsigned gray = (299u * pixel[0] + 587u * pixel[1] + 114u * pixel[2] + 500u) / 1000u;
    return gray < (unsigned)threshold;
}

static double dimension(float points, unsigned dots) {
    double mm = (double)points * 25.4 / 72.0;
    double raster_mm = (double)dots * 25.4 / 203.0;
    /* Quartz can round raster dimensions by a dot. Keep the physical page size. */
    return isfinite(mm) && mm > 0 && fabs(mm - raster_mm) < 0.3 ? mm : raster_mm;
}

static int print_page(const cups_page_header2_t *h, const Settings *s,
                      const unsigned char *bitmap, unsigned stride, int first) {
    unsigned copies = h->NumCopies ? h->NumCopies : (unsigned)s->job_copies;
    double width = dimension(h->cupsPageSize[0], h->cupsWidth);
    double height = dimension(h->cupsPageSize[1], h->cupsHeight);
    if (printf("SIZE %.3f mm,%.3f mm\r\n%s %d mm,0 mm\r\n"
               "REFERENCE 0,0\r\nDIRECTION 0,0\r\nSPEED %d\r\nDENSITY %d\r\n"
               "SET RIBBON OFF\r\nOFFSET 0 mm\r\nSET TEAR ON\r\nSET PEEL OFF\r\nSET CUTTER OFF\r\n",
               width, height, s->stock, s->gap, s->speed, s->darkness) < 0) return 0;
    /* SIZE and GAP/BLINE must precede HOME. Align once per job, never receipt stock. */
    if (first && s->gap > 0 && fputs("HOME\r\n", stdout) == EOF) return 0;
    if (printf("CLS\r\nBITMAP 0,0,%u,%u,0,", stride, h->cupsHeight) < 0) return 0;
    size_t length = (size_t)stride * h->cupsHeight;
    if (fwrite(bitmap, 1, length, stdout) != length) return 0;
    if (printf("\r\nPRINT 1,%u\r\n", copies) < 0 || fflush(stdout) != 0) return 0;
    return 1;
}

int main(int argc, char **argv) {
    if (argc == 2 && !strcmp(argv[1], "--version")) {
        puts("Open Xprinter raster filter 0.3.0 (MIT)");
        return 0;
    }
    if (argc != 6 && argc != 7) {
        fputs("Usage: rastertoxp330b job-id user title copies options [raster-file]\n", stderr);
        return 1;
    }
    struct sigaction action;
    memset(&action, 0, sizeof(action)); action.sa_handler = cancel_job;
    sigaction(SIGTERM, &action, NULL); sigaction(SIGINT, &action, NULL);
    signal(SIGPIPE, SIG_IGN);
    Settings s;
    memset(&s, 0, sizeof(s));
    if (!settings(argc, argv, &s)) return 1;
    Input input = { STDIN_FILENO, 0, 0 };
    if (argc == 7) {
        input.fd = open(argv[6], O_RDONLY | O_NOFOLLOW);
        if (input.fd < 0) { fputs("ERROR: Cannot open the raster input.\n", stderr); return 1; }
    }
    cups_raster_t *raster = cupsRasterOpenIO(read_input, &input, CUPS_RASTER_READ);
    int failed = raster == NULL, pages = 0;
    if (!raster) fputs("ERROR: Cannot open the CUPS raster stream.\n", stderr);
    while (raster && !cancelled && !failed) {
        cups_page_header2_t h;
        size_t previous_bytes = input.bytes;
        if (!cupsRasterReadHeader2(raster, &h)) {
            if (input.failed || input.bytes != previous_bytes) {
                fputs("ERROR: Incomplete raster page header.\n", stderr); failed = 1;
            }
            break;
        }
        if (++pages > 10000 || !valid_header(&h)) {
            fputs("ERROR: Unsupported raster: use 203 dpi, simplex, width up to 76 mm and height up to 1000 mm.\n", stderr);
            failed = 1; break;
        }
        unsigned stride = (h.cupsWidth + 7) / 8;
        size_t length = (size_t)stride * h.cupsHeight;
        unsigned char *row = malloc(h.cupsBytesPerLine), *bitmap = malloc(length);
        if (!row || !bitmap) {
            free(row); free(bitmap); fputs("ERROR: Out of memory.\n", stderr); failed = 1; break;
        }
        /* Buffer a complete page so a truncated page never sends a partial BITMAP. */
        memset(bitmap, 0xff, length);
        for (unsigned y = 0; y < h.cupsHeight && !cancelled; y++) {
            if (cupsRasterReadPixels(raster, row, h.cupsBytesPerLine) != h.cupsBytesPerLine) {
                fputs("ERROR: Incomplete raster bitmap; this page was not sent to the printer.\n", stderr);
                failed = 1; break;
            }
            for (unsigned x = 0; x < h.cupsWidth; x++)
                if (black_pixel(row, x, &h, s.threshold))
                    bitmap[(size_t)y * stride + x / 8] &= (unsigned char)~(0x80u >> (x % 8));
        }
        if (!failed && !cancelled) {
            if (!print_page(&h, &s, bitmap, stride, pages == 1)) {
                fputs("ERROR: Printer output closed or could not be written.\n", stderr); failed = 1;
            } else fprintf(stderr, "PAGE: %d %u\n", pages, h.NumCopies ? h.NumCopies : (unsigned)s.job_copies);
        }
        free(row); free(bitmap);
    }
    if (raster) cupsRasterClose(raster);
    if (input.fd != STDIN_FILENO) close(input.fd);
    if (!pages && !cancelled) { fputs("ERROR: No printable raster pages were received.\n", stderr); failed = 1; }
    return cancelled ? 0 : failed;
}
