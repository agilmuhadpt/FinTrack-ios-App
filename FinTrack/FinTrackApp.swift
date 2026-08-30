import SwiftUI

@main
struct FinTrackApp: App {

    @State private var store = AppStore()
    @State private var ui = UIState()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .environment(ui)
                #if DEBUG
                .task { DebugLaunch.apply(store: store, ui: ui) }
                #endif
        }
    }
}
