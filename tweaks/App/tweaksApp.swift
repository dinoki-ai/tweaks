//
//  tweaksApp.swift
//  tweaks
//
//  Created by Terence on 10/5/25.
//

import SwiftUI

@main
struct tweaksApp: App {
  @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

  var body: some Scene {
    Settings {
      EmptyView()
    }
  }
}
