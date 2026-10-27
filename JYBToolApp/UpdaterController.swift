//
//  UpdateController.swift
//  JYBToolApp
//
//  Created by kim on 2026/4/21.
//

import Observation
import Sparkle

@Observable
@MainActor
final class UpdaterController {
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
