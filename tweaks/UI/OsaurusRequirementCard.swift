//
//  OsaurusRequirementCard.swift
//  tweaks
//
//  Shown when Osaurus is not running/installed
//

import AppKit
import SwiftUI

struct OsaurusRequirementCard: View {
  @State private var isHovered = false

  private func openOsaurusWebsite() {
    if let url = URL(string: "https://osaurus.ai") {
      NSWorkspace.shared.open(url)
    }
  }

  var body: some View {
    VStack(spacing: 20) {
      // Icon and title section
      VStack(spacing: 12) {
        // Animated icon
        ZStack {
          Circle()
            .fill(FuturisticTheme.accent.opacity(0.1))
            .frame(width: 60, height: 60)

          Image(systemName: "sparkles")
            .font(.system(size: 28, weight: .medium))
            .foregroundColor(FuturisticTheme.accent)
            .rotationEffect(.degrees(isHovered ? 10 : 0))
            .animation(.easeInOut(duration: 0.3), value: isHovered)
        }

        VStack(spacing: 6) {
          Text("AI Runtime Required")
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(FuturisticTheme.text)

          Text("Install Osaurus to enable AI features")
            .font(.system(size: 13))
            .foregroundColor(FuturisticTheme.textSecondary)
        }
      }

      // Info section
      VStack(spacing: 8) {
        Label("Local-first AI runtime for Apple Silicon", systemImage: "cpu")
          .font(.system(size: 11))
          .foregroundColor(FuturisticTheme.textSecondary)

        Label("Lightning-fast inference with complete privacy", systemImage: "lock.shield.fill")
          .font(.system(size: 11))
          .foregroundColor(FuturisticTheme.textSecondary)

        Label("OpenAI-compatible API, zero cloud dependency", systemImage: "network.slash")
          .font(.system(size: 11))
          .foregroundColor(FuturisticTheme.textSecondary)
      }

      // Main CTA button
      Button(action: openOsaurusWebsite) {
        HStack(spacing: 8) {
          Image(systemName: "arrow.down.circle.fill")
            .font(.system(size: 16))
          Text("Download Osaurus")
            .font(.system(size: 14, weight: .medium))
        }
        .foregroundColor(.white)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(
          LinearGradient(
            gradient: Gradient(colors: [
              FuturisticTheme.accent,
              FuturisticTheme.accent.opacity(0.8),
            ]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
          )
        )
        .cornerRadius(FuturisticTheme.smallCornerRadius)
        .shadow(color: FuturisticTheme.accent.opacity(0.3), radius: 8, x: 0, y: 4)
        .scaleEffect(isHovered ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isHovered)
      }
      .buttonStyle(PlainButtonStyle())
      .onHover { hovering in
        isHovered = hovering
      }

      // Secondary link
      Button(action: openOsaurusWebsite) {
        HStack(spacing: 4) {
          Text("Learn more at")
            .foregroundColor(FuturisticTheme.textTertiary)
          Text("osaurus.ai")
            .foregroundColor(FuturisticTheme.accent)
            .underline()
          Image(systemName: "arrow.up.forward.square")
            .foregroundColor(FuturisticTheme.accent)
            .font(.system(size: 10))
        }
        .font(.system(size: 11))
      }
      .buttonStyle(PlainButtonStyle())
    }
    .frame(maxWidth: .infinity)
    .padding(24)
    .glassEffect()
  }
}
