#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

int main(int argc, char *argv[]) {
    const char *stdout_path = getenv("TFT_HOST_STDOUT");
    const char *stderr_path = getenv("TFT_HOST_STDERR");
    if (stdout_path != NULL && stdout_path[0] != '\0') {
        (void)freopen(stdout_path, "a", stdout);
    }
    if (stderr_path != NULL && stderr_path[0] != '\0') {
        (void)freopen(stderr_path, "a", stderr);
    }

    const char *emulator = getenv("TFT_EMULATOR");
    if (emulator == NULL || emulator[0] == '\0' || access(emulator, X_OK) != 0) {
        fputs("TFTMAC Emulator Host could not find the Android Emulator executable.\n", stderr);
        return EXIT_FAILURE;
    }

    argv[0] = (char *)emulator;
    execv(emulator, argv);
    fprintf(stderr, "TFTMAC Emulator Host could not start Android Emulator: %s\n", strerror(errno));
    return EXIT_FAILURE;
}
