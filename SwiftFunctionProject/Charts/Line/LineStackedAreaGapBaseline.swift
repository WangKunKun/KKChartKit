import UIKit

/// Refine only an unresolved gap interval. Known source runs keep their exact primitives;
/// between those runs, connect the original sign-chain bases without filling the source gap.
enum LineStackedAreaGapBaseline {
    typealias Geometry = LineStackedAreaGeometry

    static func resolve(from left: Int, through right: Int, sources: [Geometry.Contour],
                        continuous: (Int, Int) -> [Geometry.Edge]?,
                        point: (Int) -> CGPoint) -> [Geometry.Edge] {
        var knots: Set<Int> = [left, right]
        for source in sources {
            for segment in source.segments {
                // Whole continuous runs can be sliced without losing their interior knots.
                for index in [segment.indices.first, segment.indices.last].compactMap({ $0 })
                    where index > left && index < right { knots.insert(index) }
            }
        }
        let sorted = knots.sorted()
        return zip(sorted, sorted.dropFirst()).flatMap { a, b in
            continuous(a, b) ?? [Geometry.Edge(start: point(a), end: point(b), controls: nil)]
        }
    }
}
