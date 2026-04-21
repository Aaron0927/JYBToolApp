//
//  JYBToolAppApp.swift
//  JYBToolApp
//
//  Created by kim on 2026/3/13.
//

import SwiftUI
import Sparkle

@main
struct JYBToolAppApp: App {
    @StateObject private var updaterController = UpdaterController()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .commands {
            CommandGroup(after: .appInfo) {
                Button {
                    updaterController.checkForUpdates()
                } label: {
                    Label("检查更新", systemImage: "arrow.up.circle")
                }
            }
        }
    }
}
