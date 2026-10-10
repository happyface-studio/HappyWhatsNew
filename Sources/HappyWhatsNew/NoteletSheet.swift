//
//  NoteletSheet.swift
//  HappyWhatsNew
//
//  Created by Mykola Harmash on 05.05.26.
//

import SwiftUI

/// Pure presentation rules, kept free of SwiftUI so they can be unit-tested.
enum NoteletPresentation {
    /// The app version string a presented version refers to.
    static func resolvedVersion(_ version: NoteletPresentedVersion, currentAppVersion: String) -> String {
        switch version {
        case .current:
            currentAppVersion
        case .v(let providedVersion):
            providedVersion
        }
    }

    /// Notes for `version`, or an empty list when there is nothing to show.
    static func notes(
        for version: NoteletPresentedVersion?,
        in notes: [NoteletVersionNotes],
        currentAppVersion: String
    ) -> [NoteletVersionNoteItem] {
        guard let version else { return [] }
        return Helpers.getVersionNotes(
            for: resolvedVersion(version, currentAppVersion: currentAppVersion),
            in: notes
        )
    }

    /// Whether the value-based `noteletSheet(notes:version:)` should present
    /// on its own. `.current` is shown once per app version; `.v(_)` is shown
    /// whenever it is set and has notes.
    static func shouldAutoPresent(
        version: NoteletPresentedVersion?,
        notes: [NoteletVersionNotes],
        currentAppVersion: String,
        latestSeenVersion: String?
    ) -> Bool {
        guard let version else { return false }
        guard !self.notes(for: version, in: notes, currentAppVersion: currentAppVersion).isEmpty else {
            return false
        }
        if case .current = version {
            return latestSeenVersion != currentAppVersion
        }
        return true
    }
}

/// Value-based presentation: shows `.current` automatically once per app version.
struct NoteletSheet: ViewModifier {
    @State private var isPresented = false

    let notes: [NoteletVersionNotes]
    let version: NoteletPresentedVersion?
    let onDismiss: () -> Void
    let configuration: NoteletConfiguration
    let userDefaults: UserDefaults

    private var versionNotes: [NoteletVersionNoteItem] {
        NoteletPresentation.notes(
            for: version,
            in: notes,
            currentAppVersion: Helpers.getCurrentAppVersion()
        )
    }

    private var isCurrentVersionMode: Bool {
        if case .current = version {
            return true
        }

        return false
    }

    private var shouldPresent: Bool {
        NoteletPresentation.shouldAutoPresent(
            version: version,
            notes: notes,
            currentAppVersion: Helpers.getCurrentAppVersion(),
            latestSeenVersion: NoteletStorage.getLatestSeenAppVersion(userDefaults: userDefaults)
        )
    }

    func body(content: Content) -> some View {
        content
            .onAppear {
                isPresented = shouldPresent
            }
            .onChange(of: version) {
                isPresented = shouldPresent
            }
            .sheet(isPresented: $isPresented, onDismiss: handleDismiss) {
                NoteletSheetContentView(
                    versionNotes: versionNotes,
                    configuration: configuration
                )
            }
    }

    private func handleDismiss() {
        if isCurrentVersionMode {
            NoteletStorage.markCurrentVersionAsSeen(userDefaults: userDefaults)
        }

        onDismiss()
    }
}

/// Binding-based presentation for explicit requests, e.g. a "What's new"
/// button in settings. Presents whenever the binding is set to a version
/// with notes (even if it was already seen) and resets it to `nil` on
/// dismiss, so the same button works every time.
struct NoteletBoundSheet: ViewModifier {
    @Binding var version: NoteletPresentedVersion?

    let notes: [NoteletVersionNotes]
    let onDismiss: () -> Void
    let configuration: NoteletConfiguration
    let userDefaults: UserDefaults

    @State private var isPresented = false
    /// The version currently on screen. Kept separately from `version` so
    /// the sheet keeps its content while the binding is reset during dismissal.
    @State private var shownVersion: NoteletPresentedVersion?

    private func notesToShow(for version: NoteletPresentedVersion?) -> [NoteletVersionNoteItem] {
        NoteletPresentation.notes(
            for: version,
            in: notes,
            currentAppVersion: Helpers.getCurrentAppVersion()
        )
    }

    func body(content: Content) -> some View {
        content
            .onChange(of: version, initial: true) { _, newVersion in
                guard let newVersion else {
                    isPresented = false
                    return
                }
                guard !notesToShow(for: newVersion).isEmpty else {
                    // Nothing to show: reset so the next request is a change again.
                    version = nil
                    return
                }
                shownVersion = newVersion
                isPresented = true
            }
            .sheet(isPresented: $isPresented, onDismiss: handleDismiss) {
                NoteletSheetContentView(
                    versionNotes: notesToShow(for: shownVersion),
                    configuration: configuration
                )
            }
    }

    private func handleDismiss() {
        if case .current = shownVersion {
            NoteletStorage.markCurrentVersionAsSeen(userDefaults: userDefaults)
        }
        version = nil
        onDismiss()
    }
}

extension View {
    /// Attach a release-notes sheet to the modified view.
    ///
    /// With `version: .current` the sheet appears automatically once per app
    /// version: it is skipped when the current version was already seen, and
    /// marks it as seen when dismissed. For a button that should show notes
    /// on demand, use the overload that takes a `Binding` instead.
    ///
    /// - Parameter userDefaults: Storage backing the "seen version" check used
    ///   in `.current` presentation mode. Defaults to `.standard`. Pass an App
    ///   Group `UserDefaults` (e.g. `UserDefaults(suiteName: "group.com.example.myapp")`)
    ///   when the host app needs to share "seen" state with an extension
    ///   target like a widget, intent, or share extension.
    public func noteletSheet(
        notes: [NoteletVersionNotes],
        version: NoteletPresentedVersion? = nil,
        onDismiss: @escaping () -> Void = { },
        configuration: NoteletConfiguration = .init(),
        userDefaults: UserDefaults = .standard
    ) -> some View {
        modifier(
            NoteletSheet(
                notes: notes,
                version: version,
                onDismiss: onDismiss,
                configuration: configuration,
                userDefaults: userDefaults
            )
        )
    }

    /// Attach a release-notes sheet that is driven by a binding — for showing
    /// notes on demand, e.g. from a "What's new" button.
    ///
    /// Setting the binding to a version that has notes presents the sheet,
    /// even if that version was already seen. On dismiss the binding is reset
    /// to `nil`, so setting it again presents the sheet again. Dismissing a
    /// `.current` presentation still marks the current version as seen.
    ///
    /// ```swift
    /// @State private var presentedVersion: NoteletPresentedVersion?
    ///
    /// Button("What's new") { presentedVersion = .current }
    ///     .noteletSheet(notes: notes, version: $presentedVersion)
    /// ```
    public func noteletSheet(
        notes: [NoteletVersionNotes],
        version: Binding<NoteletPresentedVersion?>,
        onDismiss: @escaping () -> Void = { },
        configuration: NoteletConfiguration = .init(),
        userDefaults: UserDefaults = .standard
    ) -> some View {
        modifier(
            NoteletBoundSheet(
                version: version,
                notes: notes,
                onDismiss: onDismiss,
                configuration: configuration,
                userDefaults: userDefaults
            )
        )
    }
}
