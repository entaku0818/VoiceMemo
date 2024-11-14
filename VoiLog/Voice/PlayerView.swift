//
//  PlayerView.swift
//  VoiLog
//
//  Created by 遠藤拓弥 on 2024/11/14.
//

import Foundation
import SwiftUI
import ComposableArchitecture
struct PlayerView: View {
    let store: StoreOf<VoiceMemoReducer>

    var body: some View {
        WithViewStore(store, observe: { $0 }) { viewStore in
            VStack(spacing: 8) {
                HStack {
                    Text(viewStore.title.isEmpty ? "名称未設定" : viewStore.title)
                        .font(.headline)
                    Spacer()
                }

                HStack {
                    Text(viewStore.time.formattedTime())
                        .font(.system(.caption, design: .monospaced))

                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Rectangle()
                                .fill(Color.gray.opacity(0.2))
                                .frame(width: geometry.size.width, height: 4)

                            Rectangle()
                                .fill(Color.blue)
                                .frame(width: geometry.size.width * CGFloat(viewStore.time / viewStore.duration), height: 4)
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 2))
                    }
                    .frame(height: 4)

                    Text(viewStore.duration.formattedTime())
                        .font(.system(.caption, design: .monospaced))
                }
                .padding(.horizontal)

                HStack(spacing: 20) {
                    Spacer()

                    Button(action: {
                        viewStore.send(.onTapPlaySpeed)
                    }) {
                        Text("\(viewStore.playSpeed.description)")
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.gray.opacity(0.2))
                            .clipShape(Capsule())
                    }

                    Button(action: {
                        viewStore.send(.skipBy(-10))
                    }) {
                        Image(systemName: "gobackward.10")
                            .font(.title3)
                    }

                    Button(action: {
                        viewStore.send(.playButtonTapped)
                    }) {
                        Image(systemName: viewStore.mode.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.title)
                            .foregroundColor(.blue)
                    }

                    Button(action: {
                        viewStore.send(.skipBy(10))
                    }) {
                        Image(systemName: "goforward.10")
                            .font(.title3)
                    }

                    Button(action: {
                        viewStore.send(.toggleLoop)
                    }) {
                        Image(systemName: "repeat")
                            .font(.title3)
                            .foregroundColor(viewStore.isLooping ? .blue : .gray)
                    }

                    Spacer()
                }
            }
            .padding()
            .background(Color.white)
            .cornerRadius(12)
            .shadow(radius: 2)
            .padding(.horizontal)
        }
    }
}
