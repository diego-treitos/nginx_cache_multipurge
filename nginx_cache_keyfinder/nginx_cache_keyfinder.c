#define _XOPEN_SOURCE 500
#define _GNU_SOURCE
#include <ftw.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <sys/types.h>
#include <unistd.h>

static char key[256];
static char key2[256];
static char buf[512];
static size_t keylen;
static size_t key2len;
static size_t nbytes;
static _Bool dodelete;
static _Bool bufferr;

static int
callback(const char *fpath, const struct stat *sb, int tflag, struct FTW *ftwbuf)
{
	ssize_t bytes_read;
	FILE *fp;

	// not a file?
	if (tflag != FTW_F)
		return FTW_CONTINUE;

	fp = fopen(fpath, "r");
	if (fp == NULL)
		return FTW_CONTINUE;

	bytes_read = 0;
	// skip the header
	if (fseek(fp, 0x90L, SEEK_SET) == 0)
		bytes_read = fread(buf, 1, nbytes, fp);
	fclose(fp);

	// enough bytes? Then look for the key prefix
	if (bytes_read < (ssize_t)(keylen + key2len) || memcmp(buf, key, keylen) != 0)
		return FTW_CONTINUE;

	// look for the key suffix if present
        if (key2len) {
                char *ptr;
                char *end;

                ptr = buf + keylen;
                end = memchr(ptr, '\n', bytes_read - keylen);
                if (!end) {
	                fprintf(stderr, "Invalid cache file “%s” encountered and skipped.\n", fpath);
                	bufferr = 1;
                	return FTW_CONTINUE;
                }
                ptr = end - key2len;
                if (memcmp(ptr, key2, key2len) != 0)
                        return FTW_CONTINUE;
        }

	if (dodelete) {
		remove(fpath);
	} else {
		printf("%s\n", fpath);
	}

	return FTW_CONTINUE;
}


int
main(int argc, char *argv[])
{
	if (argc < 3 || argc > 5) {
		printf("Find/unlink nginx cache files fast\n\n"
		       "Usage: %s <path> <keyprefix> [keysuffix] [-d]\n\n"
		       "Optional parameter -d unlinks found cache files\n\n", argv[0]);
    		exit(EXIT_FAILURE);
	}

	dodelete = (argc > 3 && strcmp(argv[argc - 1], "-d") == 0);
	bufferr = 0;

	strcpy(key, "\nKEY: ");
	strncat(key, argv[2], 249);
	strcpy(key2, "");
	if (argc > (dodelete ? 4 : 3)) {
		strncat(key2, argv[argc - (dodelete ? 2 : 1)], 255);
	}
	keylen = strlen(key);
	key2len = strlen(key2);
	nbytes = sizeof(buf);

	int flags = FTW_PHYS | FTW_MOUNT;

	if (nftw(argv[1], callback, 20, flags) == -1) {
		perror("nftw");
		exit(EXIT_FAILURE);
	}

	if (bufferr) {
		exit(EXIT_FAILURE);
	}

	exit(EXIT_SUCCESS);
}
