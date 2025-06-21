import SwiftUI

struct RingProgressView: View {
    var value: CGFloat
    var lineWidth: CGFloat = 6.0
    var outerRingColor = Color.black.opacity(0.08)
    var innerRingColor = Color.orange

    var body: some View {
        ZStack {
            Circle()
                .stroke(lineWidth: self.lineWidth)
                .foregroundColor(self.outerRingColor)
            Circle()
                .trim(from: 0.0, to: CGFloat(min(self.value, 1.0)))
                .stroke(
                    style: StrokeStyle(
                        lineWidth: self.lineWidth,
                        lineCap: .square, // プログレスの角を丸くしたい場合は.round
                        lineJoin: .round
                    )
                )
                .foregroundColor(self.innerRingColor)
                .rotationEffect(.degrees(-90.0))
        }
        .padding(.all, self.lineWidth / 2)
    }
}
