//
//  QuickActionEditorView.swift
//  tweaks
//
//  Editor for 4 quick tweak slots with enable toggles
//

import SwiftUI

struct QuickActionEditorView: View {
  @ObservedObject private var settings = SettingsManager.shared

  var body: some View {
    VStack(spacing: 10) {
      ForEach(settings.quickSlots.sorted { $0.number < $1.number }, id: \.number) { slot in
        QuickActionSlotRow(slot: slot)
      }
    }
  }
}

private struct QuickActionSlotRow: View {
  let slot: QuickTweakSlot
  @State private var localTitle: String = ""
  @State private var localSubtitle: String = ""
  @State private var localPrompt: String = ""
  @State private var isEnabled: Bool = true

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      HStack(spacing: 10) {
        Toggle("", isOn: Binding(
          get: { isEnabled },
          set: { newValue in
            isEnabled = newValue
            SettingsManager.shared.updateQuickSlot(
              number: slot.number, isEnabled: newValue)
          }
        ))
        .toggleStyle(SwitchToggleStyle())
        .labelsHidden()

        Text("\(slot.number)")
          .font(.system(size: 12, weight: .semibold, design: .monospaced))
          .foregroundColor(FuturisticTheme.textSecondary)
          .frame(width: 22, alignment: .leading)

        FuturisticTextField(placeholder: "Title", text: Binding(
          get: { localTitle },
          set: { newValue in
            localTitle = newValue
            SettingsManager.shared.updateQuickSlot(
              number: slot.number, title: newValue)
          }
        ))

        FuturisticTextField(placeholder: "Subtitle", text: Binding(
          get: { localSubtitle },
          set: { newValue in
            localSubtitle = newValue
            SettingsManager.shared.updateQuickSlot(
              number: slot.number, subtitle: newValue)
          }
        ))
      }

      VStack(alignment: .leading, spacing: 6) {
        Text("System Prompt")
          .font(.system(size: 11))
          .foregroundColor(FuturisticTheme.textTertiary)
        TextEditor(text: Binding(
          get: { localPrompt },
          set: { newValue in
            localPrompt = newValue
            SettingsManager.shared.updateQuickSlot(
              number: slot.number, systemPrompt: newValue)
          }
        ))
        .font(.system(size: 12))
        .foregroundColor(FuturisticTheme.text)
        .scrollContentBackground(.hidden)
        .padding(8)
        .background(FuturisticTheme.surface)
        .cornerRadius(FuturisticTheme.smallCornerRadius)
        .overlay(
          RoundedRectangle(cornerRadius: FuturisticTheme.smallCornerRadius)
            .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
        .frame(height: 80)
      }
    }
    .padding(12)
    .background(
      RoundedRectangle(cornerRadius: FuturisticTheme.smallCornerRadius)
        .fill(FuturisticTheme.surface)
    )
    .overlay(
      RoundedRectangle(cornerRadius: FuturisticTheme.smallCornerRadius)
        .stroke(FuturisticTheme.accent.opacity(0.08), lineWidth: FuturisticTheme.borderWidth)
    )
    .onAppear {
      localTitle = slot.title
      localSubtitle = slot.subtitle
      localPrompt = slot.systemPrompt
      isEnabled = slot.isEnabled
    }
  }
}


