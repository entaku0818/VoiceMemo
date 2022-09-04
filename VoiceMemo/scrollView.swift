//
//  scrollView.swift
//  VoiceMemo
//
//  Created by 遠藤拓弥 on 3.9.2022.
//

import SwiftUI

struct scrollView: View {
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 2) {
                ForEach(1..<1000, id: \.self) { index in
                    Rectangle()
                               .fill(Color.gray)               // 図形の塗りつぶしに使うViewを指定
                               .frame(width:3, height: 50)
                }
            }
        }
    }
    
}

struct scrollView_Previews: PreviewProvider {
    static var previews: some View {
        scrollView()
    }
}
