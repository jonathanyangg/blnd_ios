import SwiftUI

// MARK: - Radar Web Shape

/// Draws the static grid: concentric polygons at each grid level + axis lines from center
struct RadarWebShape: Shape {
    let axisCount: Int
    var gridLevels: [Double] = [0.25, 0.5, 0.75, 1.0]

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2

        var path = Path()

        // Concentric polygon rings
        for level in gridLevels {
            let levelRadius = radius * CGFloat(level)
            for idx in 0 ..< axisCount {
                let angle = angleFor(index: idx, total: axisCount)
                let point = CGPoint(
                    x: center.x + levelRadius * cos(angle),
                    y: center.y + levelRadius * sin(angle)
                )
                if idx == 0 {
                    path.move(to: point)
                } else {
                    path.addLine(to: point)
                }
            }
            path.closeSubpath()
        }

        // Axis lines from center to outermost ring
        for idx in 0 ..< axisCount {
            let angle = angleFor(index: idx, total: axisCount)
            let outer = CGPoint(
                x: center.x + radius * cos(angle),
                y: center.y + radius * sin(angle)
            )
            path.move(to: center)
            path.addLine(to: outer)
        }

        return path
    }
}

// MARK: - Radar Data Shape

/// Draws the data polygon with animatable radial reveal (progress 0.0 -> 1.0)
struct RadarDataShape: Shape {
    let scores: [Double]
    var progress: Double

    var animatableData: Double {
        get { progress }
        set { progress = newValue }
    }

    func path(in rect: CGRect) -> Path {
        guard !scores.isEmpty else {
            return Path()
        }

        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2

        var path = Path()

        for idx in 0 ..< scores.count {
            let safeScore = scores[idx].isFinite ? CGFloat(scores[idx]) : 0.0
            let angle = angleFor(index: idx, total: scores.count)
            let vertexRadius = radius * safeScore * CGFloat(progress)
            let point = CGPoint(
                x: center.x + vertexRadius * cos(angle),
                y: center.y + vertexRadius * sin(angle)
            )
            if idx == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        path.closeSubpath()

        return path
    }
}

// MARK: - Radar Chart View

/// Composite radar chart: web grid + data polygon + axis labels. Animates reveal on appear.
struct RadarChartView: View {
    let scores: [Double]
    let labels: [String]

    @State private var hasAppeared = false

    /// Inset from the ZStack edge to the chart area, leaving room for labels
    private let labelInset: CGFloat = 36

    var body: some View {
        ZStack {
            // Static web grid
            RadarWebShape(axisCount: labels.count)
                .stroke(AppTheme.border, lineWidth: 1)
                .padding(labelInset)

            // Data polygon (animated)
            RadarDataShape(
                scores: scores,
                progress: hasAppeared ? 1.0 : 0.0
            )
            .fill(.white.opacity(0.15))
            .padding(labelInset)

            RadarDataShape(
                scores: scores,
                progress: hasAppeared ? 1.0 : 0.0
            )
            .stroke(.white.opacity(0.8), lineWidth: 2)
            .padding(labelInset)

            // Axis labels positioned outside the outermost ring
            ForEach(Array(labels.enumerated()), id: \.offset) { idx, label in
                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(AppTheme.textMuted)
                    .position(labelPosition(
                        index: idx,
                        total: labels.count,
                        size: 280
                    ))
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.7)) {
                hasAppeared = true
            }
        }
    }

    /// Compute label position outside the chart ring
    private func labelPosition(
        index: Int,
        total: Int,
        size: CGFloat
    ) -> CGPoint {
        let center = size / 2
        let chartRadius = (size - labelInset * 2) / 2
        let labelRadius = chartRadius + 22
        let angle = angleFor(index: index, total: total)
        return CGPoint(
            x: center + labelRadius * cos(angle),
            y: center + labelRadius * sin(angle)
        )
    }
}

// MARK: - Angle Helper

/// Compute the angle for a given axis index. First axis points straight up (-pi/2).
private func angleFor(index: Int, total: Int) -> CGFloat {
    -(CGFloat.pi / 2) + (2 * CGFloat.pi / CGFloat(total)) * CGFloat(index)
}

// MARK: - Preview

#Preview {
    RadarChartView(
        scores: [0.9, 0.6, 0.8, 0.3, 0.7, 0.5, 0.4, 0.2],
        labels: [
            "Action", "Comedy", "Drama", "Horror",
            "Sci-Fi", "Romance", "Thriller", "Animation",
        ]
    )
    .frame(width: 280, height: 280)
    .background(AppTheme.background)
}
