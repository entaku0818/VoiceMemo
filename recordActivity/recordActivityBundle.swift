//
//  recordActivityBundle.swift
//  recordActivity
//
//  Created by 遠藤拓弥 on 2024/07/20.
//

import WidgetKit
import SwiftUI

@main
struct RecordActivityBundle: WidgetBundle {
    var body: some Widget {
        RecordActivity()
        RecordActivityLiveActivity()
    }
}
