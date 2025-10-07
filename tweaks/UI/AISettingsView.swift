//
//  AISettingsView.swift
//  tweaks
//
//  AI model selection, prompts, and temperature
//

import SwiftUI

// MARK: - AI Settings View and subviews

struct AISettingsView: View {
  @ObservedObject private var settingsManager = SettingsManager.shared
  @State private var showingPromptEditor = false

  var body: some View {
    VStack(spacing: 20) {
      // Model Selection
      VStack(alignment: .leading, spacing: 12) {
        Label("AI Model", systemImage: "cpu")
          .font(.system(size: 14, weight: .semibold))
          .foregroundColor(FuturisticTheme.text)

        if settingsManager.isLoadingModels {
          HStack {
            ProgressView()
              .scaleEffect(0.8)
            Text("Loading models...")
              .font(.system(size: 12))
              .foregroundColor(FuturisticTheme.textSecondary)
          }
          .frame(maxWidth: .infinity)
          .padding()
          .glassEffect()
        } else if let error = settingsManager.modelsFetchError {
          VStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle")
              .font(.system(size: 24))
              .foregroundColor(FuturisticTheme.warning)
            Text(error)
              .font(.system(size: 11))
              .foregroundColor(FuturisticTheme.textSecondary)
              .multilineTextAlignment(.center)
            FuturisticButton(
              title: "Retry",
              icon: "arrow.clockwise",
              action: {
                Task {
                  await settingsManager.fetchAvailableModels()
                }
              },
              style: .secondary
            )
          }
          .frame(maxWidth: .infinity)
          .padding()
          .glassEffect()
        } else {
          VStack(spacing: 8) {
            ForEach(settingsManager.availableModels) { model in
              ModelRow(
                model: model,
                isSelected: settingsManager.selectedModelId == model.id,
                onSelect: {
                  settingsManager.selectModel(model.id)
                }
              )
            }
          }
        }
      }

      // System Prompts
      PromptEditorView()
        .padding()
        .glassEffect()

      // Temperature Control
      VStack(alignment: .leading, spacing: 12) {
        HStack {
          Label("Temperature", systemImage: "thermometer")
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(FuturisticTheme.text)

          Spacer()

          Text(String(format: "%.1f", settingsManager.temperature))
            .font(.system(size: 12, weight: .medium, design: .monospaced))
            .foregroundColor(FuturisticTheme.accent)
        }

        Slider(
          value: Binding(
            get: { settingsManager.temperature },
            set: { settingsManager.updateTemperature($0) }
          ), in: 0...2, step: 0.1
        )
        .accentColor(FuturisticTheme.accent)

        HStack {
          Text("Precise")
            .font(.system(size: 10))
          Spacer()
          Text("Creative")
            .font(.system(size: 10))
        }
        .foregroundColor(FuturisticTheme.textTertiary)
      }
      .padding()
      .glassEffect()
    }
  }
}

struct ModelRow: View {
  let model: OsaurusModel
  let isSelected: Bool
  let onSelect: () -> Void

  var body: some View {
    HStack {
      VStack(alignment: .leading, spacing: 2) {
        Text(model.displayName)
          .font(.system(size: 13, weight: .medium))
          .foregroundColor(FuturisticTheme.text)

        if let owner = model.owned_by {
          Text("by \(owner)")
            .font(.system(size: 10))
            .foregroundColor(FuturisticTheme.textTertiary)
        }
      }

      Spacer()

      if isSelected {
        Image(systemName: "checkmark.circle.fill")
          .font(.system(size: 14))
          .foregroundColor(FuturisticTheme.accent)
      }
    }
    .padding(12)
    .background(
      RoundedRectangle(cornerRadius: FuturisticTheme.smallCornerRadius)
        .fill(isSelected ? FuturisticTheme.accent.opacity(0.1) : FuturisticTheme.surface)
    )
    .overlay(
      RoundedRectangle(cornerRadius: FuturisticTheme.smallCornerRadius)
        .stroke(
          isSelected ? FuturisticTheme.accent.opacity(0.3) : Color.clear,
          lineWidth: 1
        )
    )
    .onTapGesture {
      onSelect()
    }
  }
}
