import Foundation
import SwiftUI

@main
struct RoundelApp: App {
    @State private var store = MarkStore(fileURL: RoundelApp.marksFileURL)

    /// Where the marks live is the app's decision, not the store's — and the
    /// TODO's sync item turns this into a user-chosen location.
    private static var marksFileURL: URL {
        let directory = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("roundel.csv")
    }

    var body: some Scene {
        MenuBarExtra("Roundel", systemImage: "calendar") {
            CalendarPopoverView()
                .environment(store)
        }
        .menuBarExtraStyle(.window)

        // A plain window rather than the Settings scene: this panel reports data
        // rather than holding preferences, and Settings would force the title to
        // be "Roundel Settings".
        Window(DashboardView.windowTitle, id: DashboardView.windowID) {
            DashboardView()
                .environment(store)
        }
        .windowResizability(.contentSize)
        .defaultPosition(.center)
    }
}
