import Observation
import SwiftUI

@MainActor
@Observable
final class IllustDetailTransitionCoordinator {
    var requestedIllustID: Int?

    func prepareReturnSource(for illustID: Int) {
        guard requestedIllustID != illustID else { return }
        requestedIllustID = illustID
    }

    func resetReturnSource() {
        requestedIllustID = nil
    }
}

struct IllustDetailTransitionSource: Hashable {
    let scopeID: UUID
    let namespace: Namespace.ID
    let coordinator: IllustDetailTransitionCoordinator

    func sourceID(for illustID: Int) -> AnyHashable {
        AnyHashable(IllustDetailTransitionSourceID(scopeID: scopeID, illustID: illustID))
    }

    static func == (lhs: IllustDetailTransitionSource, rhs: IllustDetailTransitionSource) -> Bool {
        lhs.scopeID == rhs.scopeID
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(scopeID)
    }
}

extension EnvironmentValues {
    @Entry var illustDetailTransitionSource: IllustDetailTransitionSource?
}

extension View {
    @ViewBuilder
    func illustDetailNavigationSourceScope() -> some View {
        #if os(iOS)
        modifier(IllustDetailSourceScopeModifier())
        #else
        self
        #endif
    }
}

private struct IllustDetailTransitionSourceID: Hashable {
    let scopeID: UUID
    let illustID: Int
}

private struct IllustDetailSourceScopeModifier: ViewModifier {
    @Namespace private var namespace
    @State private var scopeID = UUID()
    @State private var coordinator = IllustDetailTransitionCoordinator()

    func body(content: Content) -> some View {
        let source = IllustDetailTransitionSource(
            scopeID: scopeID,
            namespace: namespace,
            coordinator: coordinator
        )

        ScrollViewReader { proxy in
            content
                .environment(\.illustDetailTransitionSource, source)
                .onChange(of: coordinator.requestedIllustID) { _, illustID in
                    guard let illustID else { return }
                    proxy.scrollTo(source.sourceID(for: illustID), anchor: .center)
                }
        }
    }
}
