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
   let memo: VoiceMemoReducer.State
   let store: StoreOf<VoiceMemos>

   var body: some View {
       VStack(spacing: 8) {
           HStack {
               Text(memo.title.isEmpty ? "名称未設定" : memo.title)
                   .font(.headline)
               Spacer()
           }

           HStack {
               Text(memo.time.formattedTime())
                   .font(.system(.caption, design: .monospaced))

               GeometryReader { geometry in
                   ZStack(alignment: .leading) {
                       Rectangle()
                           .fill(Color.gray.opacity(0.2))
                           .frame(width: geometry.size.width, height: 4)

                       Rectangle()
                           .fill(Color.blue)
                           .frame(width: geometry.size.width * CGFloat(memo.time / memo.duration), height: 4)
                   }
                   .clipShape(RoundedRectangle(cornerRadius: 2))
               }
               .frame(height: 4)

               Text(memo.duration.formattedTime())
                   .font(.system(.caption, design: .monospaced))
           }
           .padding(.horizontal)

           HStack(spacing: 20) {
               Spacer()

               Button(action: {
                   store.send(.voiceMemos(id: memo.id, action: .onTapPlaySpeed))
               }) {
                   Text("\(memo.playSpeed.description)")
                       .font(.caption)
                       .padding(.horizontal, 8)
                       .padding(.vertical, 4)
                       .background(Color.gray.opacity(0.2))
                       .clipShape(Capsule())
               }

               Button(action: {
                   store.send(.voiceMemos(id: memo.id, action: .skipBy(-10)))
               }) {
                   Image(systemName: "gobackward.10")
                       .font(.title3)
               }

               Button(action: {
                   store.send(.voiceMemos(id: memo.id, action: .playButtonTapped))
               }) {
                   Image(systemName: memo.mode.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                       .font(.title)
                       .foregroundColor(.blue)
               }

               Button(action: {
                   store.send(.voiceMemos(id: memo.id, action: .skipBy(10)))
               }) {
                   Image(systemName: "goforward.10")
                       .font(.title3)
               }

               Button(action: {
                   store.send(.voiceMemos(id: memo.id, action: .toggleLoop))
               }) {
                   Image(systemName: "repeat")
                       .font(.title3)
                       .foregroundColor(memo.isLooping ? .blue : .gray)
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
