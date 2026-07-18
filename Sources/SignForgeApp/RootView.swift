import SwiftUI

struct RootView: View {
    var body: some View {
        WorkstationView()
    }
}

struct MetricRow: View {
    var label: String
    var value: Int
    var body: some View { HStack { Text(label); Spacer(); Text(value, format: .number).foregroundStyle(.secondary) } }
}
