//
//  WaveformView.swift
//  VoiLog
//
//  Created by 遠藤拓弥 on 8.7.2023.
//

import SwiftUI

struct WaveformView: View {
    var waveformData: [Float]

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                // 背景
                Rectangle()
                    .fill(Color.gray)


                VStack{
                    Spacer()
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 2) {

                            ForEach(waveformData, id: \.self) { volume in
                                let height: CGFloat = CGFloat(volume * 30) + 1
                                Rectangle()
                                    .fill(Color.pink)               // 図形の塗りつぶしに使うViewを指定
                                    .frame(width: 3, height: height)
                            }
                        }

                    }
                    Spacer()
                }
                // 基準線
                Path { path in
                    let height = geometry.size.height
                    let centerY = height / 2.0

                    path.move(to: CGPoint(x: 0, y: centerY))
                    path.addLine(to: CGPoint(x: geometry.size.width, y: centerY))
                }
                .stroke(Color.white, lineWidth: 1)
            }
        }
    }
}

struct WaveformView_Previews: PreviewProvider {
    static var previews: some View {
        WaveformView(waveformData: [0.2, 0.5, 0.8, 0.3, 0.6])
            .frame(width: 300, height: 200)
            .padding()
            .background(Color.white)
    }
}
