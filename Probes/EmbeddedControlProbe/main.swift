import Foundation

let authority = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    .appendingPathComponent("Vendor/AndroidEmulator/SOURCE.json")

if FileManager.default.fileExists(atPath: authority.path) {
    print("TFTMAC EmbeddedControlProbe: emulator protocol authority present")
    exit(EXIT_SUCCESS)
} else {
    fputs("TFTMAC EmbeddedControlProbe: emulator protocol authority missing\n", stderr)
    exit(EXIT_FAILURE)
}
