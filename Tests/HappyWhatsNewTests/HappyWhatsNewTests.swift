import Foundation
import Testing
@testable import HappyWhatsNew

private let notes: [NoteletVersionNotes] = [
    .init(
        version: "1.2.0",
        items: [
            .list(
                title: "What's new",
                rows: [.init(symbolSystemName: "sparkles", title: "Polish", description: "Small upgrades.")]
            )
        ]
    ),
    .init(
        version: "1.1.0",
        items: [
            .media(
                kind: .image,
                url: URL(string: "https://example.com/a.jpg")!,
                title: "Archive",
                description: "Archive entries."
            )
        ]
    ),
]

@Suite("Automatic presentation (value API)")
struct AutoPresentationTests {
    @Test func currentVersionShowsWhenUnseen() {
        #expect(NoteletPresentation.shouldAutoPresent(
            version: .current, notes: notes, currentAppVersion: "1.2.0", latestSeenVersion: "1.1.0"
        ))
        #expect(NoteletPresentation.shouldAutoPresent(
            version: .current, notes: notes, currentAppVersion: "1.2.0", latestSeenVersion: nil
        ))
    }

    @Test func currentVersionIsSkippedOnceSeen() {
        #expect(!NoteletPresentation.shouldAutoPresent(
            version: .current, notes: notes, currentAppVersion: "1.2.0", latestSeenVersion: "1.2.0"
        ))
    }

    @Test func versionsWithoutNotesNeverShow() {
        #expect(!NoteletPresentation.shouldAutoPresent(
            version: .current, notes: notes, currentAppVersion: "9.9.9", latestSeenVersion: nil
        ))
        #expect(!NoteletPresentation.shouldAutoPresent(
            version: .v("0.1.0"), notes: notes, currentAppVersion: "1.2.0", latestSeenVersion: nil
        ))
        #expect(!NoteletPresentation.shouldAutoPresent(
            version: nil, notes: notes, currentAppVersion: "1.2.0", latestSeenVersion: nil
        ))
    }

    @Test func explicitVersionShowsEvenIfSeen() {
        #expect(NoteletPresentation.shouldAutoPresent(
            version: .v("1.1.0"), notes: notes, currentAppVersion: "1.2.0", latestSeenVersion: "1.2.0"
        ))
    }
}

@Suite("Note lookup")
struct NoteLookupTests {
    @Test func resolvesCurrentAndExplicitVersions() {
        #expect(NoteletPresentation.resolvedVersion(.current, currentAppVersion: "1.2.0") == "1.2.0")
        #expect(NoteletPresentation.resolvedVersion(.v("1.1.0"), currentAppVersion: "1.2.0") == "1.1.0")
    }

    @Test func returnsItemsForMatchingVersionOnly() {
        #expect(NoteletPresentation.notes(for: .v("1.1.0"), in: notes, currentAppVersion: "1.2.0").count == 1)
        #expect(NoteletPresentation.notes(for: .current, in: notes, currentAppVersion: "1.2.0").count == 1)
        #expect(NoteletPresentation.notes(for: nil, in: notes, currentAppVersion: "1.2.0").isEmpty)
    }
}

@Suite("Storage")
struct StorageTests {
    private func freshDefaults() -> UserDefaults {
        let suite = "HappyWhatsNewTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }

    @Test func storageKeyIsUnchangedByTheRename() {
        // Changing this key would show already-seen notes again to every user.
        #expect(NoteletStorageKey.latestSeenAppVersion == "Notelet.LatestSeenAppVersion")
    }

    @Test func markAndResetSeenVersion() {
        let defaults = freshDefaults()
        #expect(NoteletStorage.getLatestSeenAppVersion(userDefaults: defaults) == nil)

        NoteletStorage.markCurrentVersionAsSeen(userDefaults: defaults)
        #expect(NoteletStorage.getLatestSeenAppVersion(userDefaults: defaults) == Helpers.getCurrentAppVersion())

        NoteletStorage.resetSeenVersion(userDefaults: defaults)
        #expect(NoteletStorage.getLatestSeenAppVersion(userDefaults: defaults) == nil)
    }
}

@Suite("Codable")
struct CodableTests {
    @Test func versionNotesRoundTrip() throws {
        let data = try JSONEncoder().encode(notes)
        let decoded = try JSONDecoder().decode([NoteletVersionNotes].self, from: data)
        #expect(decoded.map(\.version) == ["1.2.0", "1.1.0"])
        #expect(decoded.map(\.items.count) == [1, 1])
    }
}
