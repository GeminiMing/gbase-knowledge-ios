import SwiftUI

struct WaveformView: View {
    let samples: [CGFloat]
    var color: Color = .red

    private let spacing: CGFloat = 6

    var body: some View {
        GeometryReader { geometry in
            let barWidth = max(4, (geometry.size.width - spacing * CGFloat(max(samples.count - 1, 0))) / CGFloat(max(samples.count, 1)))
            let maxHeight = geometry.size.height

            HStack(alignment: .center, spacing: spacing) {
                ForEach(Array(samples.enumerated()), id: \.offset) { _, sample in
                    Capsule()
                        .fill(color.gradient)
                        .frame(width: barWidth,
                               height: max(8, maxHeight * max(0.05, min(1, sample))))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
        .frame(height: 80)
        .accessibilityLabel(LocalizedStringKey.waveformAccessibilityLabel.localized)
    }
}

#Preview {
    WaveformView(samples: (0..<24).map { _ in .random(in: 0.1...1) })
        .padding()
}

