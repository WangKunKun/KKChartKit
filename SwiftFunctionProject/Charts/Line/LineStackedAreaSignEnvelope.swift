import UIKit

/// The two continuous surfaces after a resolved area interval. An inactive sign keeps the
/// previous surface, rather than borrowing the other sign's disconnected stroke.
/// This is geometry metadata for this draw only; it never creates data/hit samples.
struct LineStackedAreaSignEnvelope {
    typealias Edge = LineStackedAreaGeometry.Edge
    let positive: [Edge]?
    let negative: [Edge]?

    static func crossing(thickness: [Edge], positive: [Edge], negative: [Edge],
                         startsPositive: Bool) -> Self? {
        guard let halves = LineStackedAreaTransitions.splitAtZero(thickness) else { return nil }
        func zero(_ edges: [Edge]) -> [Edge] {
            edges.map { Edge(start: CGPoint(x: $0.start.x, y: 0),
                             end: CGPoint(x: $0.end.x, y: 0), controls: nil) }
        }
        let first = halves.0 + zero(halves.1), second = zero(halves.0) + halves.1
        guard let p = LineStackedAreaGeometry.adding(positive, startsPositive ? first : second),
              let n = LineStackedAreaGeometry.adding(negative, startsPositive ? second : first) else { return nil }
        return Self(positive: p, negative: n)
    }
}
