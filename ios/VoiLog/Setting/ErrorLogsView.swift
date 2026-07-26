//
//  ErrorLogsView.swift
//  VoiLog
//
//  Created by 遠藤拓弥 on 2024/07/21.
//

import Foundation
import SwiftUI
import Dependencies

struct ErrorLogsView: View {
    @ObservedObject private var viewModel = ErrorLogsViewModel()

    var body: some View {
        NavigationView {
            List(viewModel.errorLogs, id: \.self) { log in
                Text(log)
                    .font(.body)
                    .padding()
            }
            .navigationTitle("Error Logs")
        }
        .onAppear {
            viewModel.fetchErrorLogs()
        }
    }
}

class ErrorLogsViewModel: ObservableObject {
    @Dependency(\.userDefaults) var userDefaults
    @Published var errorLogs: [String] = []

    func fetchErrorLogs() {
        errorLogs = userDefaults.errorLogs()
    }
}

struct ErrorLogsView_Previews: PreviewProvider {
    static var previews: some View {
        ErrorLogsView()
    }
}
