import SwiftUI

@main
struct SignForgeApp: App {
    @State private var store = VaultStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
        }
    }
}
