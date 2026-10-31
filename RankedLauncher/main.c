#include <errno.h>
#include <limits.h>
#include <mach-o/dyld.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

#ifdef TFTMAC_TURBO2
static const char *const kRuntimeMode = "turbo2";
#else
static const char *const kRuntimeMode = "advanced_diagnostics";
#endif
static const char *const kCoreExecutable = "TFTMACDEVCore";

int main(int argc, char *argv[]) {
    if (setenv("TFTMAC_AUTONOMOUS_SILENT", "0", 1) != 0) return 70;
#ifdef TFTMAC_TURBO2
    if (setenv("TFTMAC_DEV_DIRECT_HOST", "0", 1) != 0) return 70;
    unsetenv("TFTMAC_ANGLE_DRIVER_MANIFEST");
#else
    if (setenv("TFTMAC_DEV_DIRECT_HOST", "1", 1) != 0) return 70;
#endif
    if (setenv("TFTMAC_DEV_DISPLAY", "1920x1080", 1) != 0) return 70;
    if (setenv("TFTMAC_DEV_VCPU", "8", 1) != 0) return 70;
    if (setenv("TFTMAC_DEV_RAM_MIB", "6144", 1) != 0) return 70;
    if (setenv("TFTMAC_DEV_FRAME_POLL_DEADLINE", "1", 1) != 0) return 70;
    if (setenv("TFTMAC_DEV_ASG_FLUSH", "2000", 0) != 0) return 70;
    if (setenv("TFTMAC_DEV_ASG_DATA_RING", "262144", 0) != 0) return 70;
    if (setenv("TFTMAC_DEV_ASG_WRITE_STEP", "65536", 0) != 0) return 70;
    if (setenv("TFTMAC_DEV_ASG_WRITE_BUFFER", "1048576", 0) != 0) return 70;
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

#ifndef TFTMAC_TURBO2
    char angleManifestPath[PATH_MAX];
    int manifestWritten = snprintf(angleManifestPath, sizeof(angleManifestPath), "%s/../Resources/ANGLEDriver/angle-driver-manifest.json", resolvedPath);
    if (manifestWritten > 0 && (size_t)manifestWritten < sizeof(angleManifestPath)) {
        char resolvedManifest[PATH_MAX];
        if (realpath(angleManifestPath, resolvedManifest) != NULL) {
            setenv("TFTMAC_ANGLE_DRIVER_MANIFEST", resolvedManifest, 0);
        }
    }

#endif
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
