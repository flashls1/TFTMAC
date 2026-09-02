#include <errno.h>
#include <limits.h>
#include <mach-o/dyld.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

static const char *const kRuntimeMode = "advanced_diagnostics";
static const char *const kCoreExecutable = "TFTMACDEVCore";

int main(int argc, char *argv[]) {
    char launcherPath[PATH_MAX];
    uint32_t launcherPathSize = (uint32_t)sizeof(launcherPath);
    if (_NSGetExecutablePath(launcherPath, &launcherPathSize) != 0) {
        fprintf(stderr, "TFTMAC DEV could not resolve its launcher path.\n");
        return 70;
    }

    char resolvedPath[PATH_MAX];
    if (realpath(launcherPath, resolvedPath) == NULL) {
        fprintf(stderr, "TFTMAC DEV could not canonicalize its launcher path: %s\n", strerror(errno));
        return 70;
    }

    char *lastSlash = strrchr(resolvedPath, '/');
    if (lastSlash == NULL) {
        fprintf(stderr, "TFTMAC DEV launcher path has no containing directory.\n");
        return 70;
    }
    *lastSlash = '\0';

    char corePath[PATH_MAX];
    int written = snprintf(corePath, sizeof(corePath), "%s/%s", resolvedPath, kCoreExecutable);
    if (written < 0 || (size_t)written >= sizeof(corePath)) {
        fprintf(stderr, "TFTMAC DEV core path is too long.\n");
        return 70;
    }
    if (access(corePath, X_OK) != 0) {
        fprintf(stderr, "TFTMAC DEV core is missing or not executable: %s\n", corePath);
        return 70;
    }

    if (setenv("TFTMAC_RUNTIME_MODE", kRuntimeMode, 1) != 0) {
        fprintf(stderr, "TFTMAC DEV could not select its isolated runtime mode: %s\n", strerror(errno));
        return 70;
    }

    char **coreArguments = calloc((size_t)argc + 1, sizeof(char *));
    if (coreArguments == NULL) {
        fprintf(stderr, "TFTMAC DEV could not allocate its launch arguments.\n");
        return 70;
    }
    coreArguments[0] = corePath;
    for (int index = 1; index < argc; index += 1) {
        coreArguments[index] = argv[index];
    }

    execv(corePath, coreArguments);
    fprintf(stderr, "TFTMAC DEV could not start its core: %s\n", strerror(errno));
    free(coreArguments);
    return 70;
}
