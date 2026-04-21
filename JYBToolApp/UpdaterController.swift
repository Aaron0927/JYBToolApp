//
//  UpdateController.swift
//  JYBToolApp
//
//  Created by kim on 2026/4/21.
//

import Combine
import Sparkle

final class UpdaterController: ObservableObject {
    private let updaterController: SPUStandardUpdaterController
    
    init() {
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
    }
    
    func checkForUpdates() {
        updaterController.checkForUpdates(nil)
    }
}
