import Foundation
import Combine

@MainActor
final class MenuBarSnapshot: ObservableObject {
    @Published var selected: [BarMetric]

    init(selected: [BarMetric]) {
        self.selected = selected
    }
}
