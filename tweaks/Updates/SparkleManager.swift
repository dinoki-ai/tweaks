//
//  SparkleManager.swift
//  tweaks
//
//  Created on 10/7/25.
//

import Foundation
import Sparkle

/// Manages Sparkle updates for the app
class SparkleManager: ObservableObject {
  static let shared = SparkleManager()

  let updaterController: SPUStandardUpdaterController

  @Published var canCheckForUpdates = false
  @Published var lastUpdateCheckDate: Date?
  @Published var automaticUpdateChecks = true
  @Published var isCheckingForUpdates = false

  private init() {
    updaterController = SPUStandardUpdaterController(
      startingUpdater: true,
      updaterDelegate: nil,
      userDriverDelegate: nil
    )

    setupBindings()
  }

  private func setupBindings() {
    // Monitor update checking state
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(updateCheckStarted),
      name: .init("SUUpdaterWillCheckForUpdates"),
      object: updater
    )

    NotificationCenter.default.addObserver(
      self,
      selector: #selector(updateCheckEnded),
      name: .init("SUUpdaterDidFinishUpdateCheck"),
      object: updater
    )

    // Set initial values
    canCheckForUpdates = updater.canCheckForUpdates
    automaticUpdateChecks = updater.automaticallyChecksForUpdates
    lastUpdateCheckDate = updater.lastUpdateCheckDate
  }

  var updater: SPUUpdater {
    updaterController.updater
  }

  func checkForUpdates() {
    updaterController.checkForUpdates(nil)
  }

  func setAutomaticUpdateChecks(_ enabled: Bool) {
    updater.automaticallyChecksForUpdates = enabled
    automaticUpdateChecks = enabled
  }

  func resetUpdateCycle() {
    updater.resetUpdateCycle()
  }

  @objc private func updateCheckStarted() {
    DispatchQueue.main.async {
      self.isCheckingForUpdates = true
    }
  }

  @objc private func updateCheckEnded() {
    DispatchQueue.main.async {
      self.isCheckingForUpdates = false
      self.lastUpdateCheckDate = self.updater.lastUpdateCheckDate
    }
  }

  deinit {
    NotificationCenter.default.removeObserver(self)
  }
}

// MARK: - Sparkle UI Integration
extension SparkleManager {
  /// Shows the standard Sparkle update permission prompt if needed
  func showUpdatePermissionPromptIfNeeded() {
    if !updater.automaticallyChecksForUpdates && updater.canCheckForUpdates {
      updater.automaticallyChecksForUpdates = true
    }
  }

  /// Get a human-readable string for the last update check
  var lastUpdateCheckString: String {
    guard let date = lastUpdateCheckDate else { return "Never" }

    let formatter = RelativeDateTimeFormatter()
    formatter.unitsStyle = .full
    return formatter.localizedString(for: date, relativeTo: Date())
  }

  /// Current update status string
  var updateStatusString: String {
    if isCheckingForUpdates {
      return "Checking for updates..."
    } else if let date = lastUpdateCheckDate {
      return "Last checked \(lastUpdateCheckString)"
    } else {
      return "Updates not yet checked"
    }
  }
}
