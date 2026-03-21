import Testing
@testable import XcodeCLICore

@Suite("Version")
struct VersionTests {
    @Test("source version is a valid semver string")
    func sourceVersionFormat() {
        #expect(Version.source.hasPrefix("v"))
        #expect(Version.source.contains("."))
    }

    @Test("current version defaults to source version in dev builds")
    func currentDefaultsToSource() {
        #expect(Version.current == Version.source)
    }

    @Test("version line includes xcodecli prefix")
    func versionLineFormat() {
        #expect(Version.line.hasPrefix("xcodecli "))
        #expect(Version.line.contains(Version.current))
    }

    @Test("dev channel is detected correctly")
    func devChannelDetection() {
        // In dev builds (no sed replacement), buildChannel is "dev"
        #expect(Version.buildChannel == "dev")
        #expect(Version.isDev)
    }

    @Test("version line includes dev suffix in dev builds")
    func devBuildSuffix() {
        #expect(Version.line.hasSuffix("(dev)"))
    }
}
