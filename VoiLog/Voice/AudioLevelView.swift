//
//  File.swift
//  VoiLog
//
//  Created by 遠藤拓弥 on 2024/07/21.
//

import Foundation
import SwiftUI

struct AudioLevelView: View {
    var audioLevel: Float

    let minLevel: Float = -60
    let maxLevel: Float = 0

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Rectangle()
                    .foregroundColor(.gray)
                    .opacity(0.3)
                Rectangle()
                    .foregroundColor(.blue)
                    .frame(width: normalizedWidth(for: audioLevel, in: geometry.size.width))
                    .animation(.easeInOut(duration: 0.2), value: audioLevel)
            }
            .cornerRadius(10)
        }
    }

    private func normalizedWidth(for audioLevel: Float, in totalWidth: CGFloat) -> CGFloat {
        let clampedLevel = max(min(audioLevel, maxLevel), minLevel)
        return CGFloat((clampedLevel - minLevel) / (maxLevel - minLevel)) * totalWidth
    }
}

struct AudioLevelView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            AudioLevelView(audioLevel: -50)
                .frame(height: 20)
                .previewDisplayName("Low Level")

            AudioLevelView(audioLevel: -30)
                .frame(height: 20)
                .previewDisplayName("Medium Level")

            AudioLevelView(audioLevel: -10)
                .frame(height: 20)
                .previewDisplayName("High Level")

            AudioLevelView(audioLevel: 0)
                .frame(height: 20)
                .previewDisplayName("Max Level")
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
