//
//  QuickActionEditorView.swift
//  tweaks
//
//  Editor for 4 quick tweak slots with enable toggles
//

import SwiftUI

struct QuickActionEditorView: View {
  @ObservedObject private var settings = SettingsManager.shared
  @State private var isHoveringReset = false

  var body: some View {
    VStack(spacing: 0) {
      // Header
      HStack(alignment: .top) {
        VStack(alignment: .leading, spacing: 8) {
          Label("Quick Actions", systemImage: "rectangle.grid.2x2")
            .font(.system(size: 14, weight: .semibold))
            .foregroundColor(FuturisticTheme.text)

          Text("Configure up to 4 quick actions accessible from the menu")
            .font(.system(size: 11))
            .foregroundColor(FuturisticTheme.textSecondary)
        }

        Spacer()

        Button(action: {
          settings.resetQuickSlotsToDefaults()
        }) {
          HStack(spacing: 6) {
            Image(systemName: "arrow.counterclockwise")
              .font(.system(size: 11, weight: .medium))
            Text("Reset All")
              .font(.system(size: 11, weight: .medium))
          }
          .foregroundColor(isHoveringReset ? FuturisticTheme.accent : FuturisticTheme.textSecondary)
          .padding(.horizontal, 12)
          .padding(.vertical, 6)
          .background(
            RoundedRectangle(cornerRadius: FuturisticTheme.smallCornerRadius)
              .fill(isHoveringReset ? FuturisticTheme.accent.opacity(0.1) : FuturisticTheme.surface)
          )
          .overlay(
            RoundedRectangle(cornerRadius: FuturisticTheme.smallCornerRadius)
              .stroke(
                isHoveringReset
                  ? FuturisticTheme.accent.opacity(0.4) : FuturisticTheme.accent.opacity(0.2),
                lineWidth: 1)
          )
        }
        .buttonStyle(PlainButtonStyle())
        .onHover { hovering in
          withAnimation(.easeInOut(duration: 0.15)) {
            isHoveringReset = hovering
          }
        }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(.bottom, 16)

      // Slots
      VStack(spacing: 12) {
        ForEach(settings.quickSlots.sorted { $0.number < $1.number }, id: \.number) { slot in
          QuickActionSlotCard(slot: slot)
        }
      }
    }
  }
}

private struct QuickActionSlotCard: View {
  let slot: QuickTweakSlot
  @State private var localTitle: String = ""
  @State private var localSubtitle: String = ""
  @State private var localPrompt: String = ""
  @State private var isEnabled: Bool = true
  @State private var isExpanded: Bool = false
  @State private var isHovering: Bool = false

  var body: some View {
    VStack(spacing: 0) {
      // Header
      HStack(spacing: 12) {
        // Slot Number Badge
        ZStack {
          Circle()
            .fill(isEnabled ? FuturisticTheme.accent.opacity(0.2) : Color.gray.opacity(0.1))
            .frame(width: 32, height: 32)

          Text("\(slot.number)")
            .font(.system(size: 14, weight: .bold, design: .monospaced))
            .foregroundColor(isEnabled ? FuturisticTheme.accent : FuturisticTheme.textTertiary)
        }
        .animation(.easeInOut(duration: 0.2), value: isEnabled)

        // Title and Subtitle
        VStack(alignment: .leading, spacing: 2) {
          Text(localTitle.isEmpty ? "Untitled Action" : localTitle)
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(isEnabled ? FuturisticTheme.text : FuturisticTheme.textSecondary)
            .lineLimit(1)

          Text(localSubtitle.isEmpty ? "No description" : localSubtitle)
            .font(.system(size: 11))
            .foregroundColor(FuturisticTheme.textSecondary)
            .lineLimit(1)
        }

        Spacer()

        // Toggle
        Toggle("", isOn: $isEnabled)
          .toggleStyle(SwitchToggleStyle())
          .labelsHidden()
          .onChange(of: isEnabled) { _, newValue in
            SettingsManager.shared.updateQuickSlot(
              number: slot.number, isEnabled: newValue)
          }

        // Expand/Collapse Button
        Button(action: {
          withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
            isExpanded.toggle()
          }
        }) {
          Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(FuturisticTheme.textSecondary)
            .frame(width: 24, height: 24)
            .background(FuturisticTheme.surface)
            .cornerRadius(6)
        }
        .buttonStyle(PlainButtonStyle())
      }
      .padding(16)
      .background(isHovering ? FuturisticTheme.surface.opacity(0.5) : Color.clear)
      .onHover { hovering in
        withAnimation(.easeInOut(duration: 0.15)) {
          isHovering = hovering
        }
      }

      // Expanded Content
      if isExpanded {
        VStack(spacing: 16) {
          Divider()
            .background(FuturisticTheme.accent.opacity(0.1))

          // Title and Subtitle Fields
          VStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
              Text("Title")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(FuturisticTheme.textSecondary)

              FuturisticTextField(
                placeholder: "Enter action title",
                text: Binding(
                  get: { localTitle },
                  set: { newValue in
                    localTitle = newValue
                    SettingsManager.shared.updateQuickSlot(
                      number: slot.number, title: newValue)
                  }
                )
              )
              .disabled(!isEnabled)
            }

            VStack(alignment: .leading, spacing: 6) {
              Text("Description")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(FuturisticTheme.textSecondary)

              FuturisticTextField(
                placeholder: "Brief description of this action",
                text: Binding(
                  get: { localSubtitle },
                  set: { newValue in
                    localSubtitle = newValue
                    SettingsManager.shared.updateQuickSlot(
                      number: slot.number, subtitle: newValue)
                  }
                )
              )
              .disabled(!isEnabled)
            }
          }

          // System Prompt
          VStack(alignment: .leading, spacing: 8) {
            HStack {
              Label("System Prompt", systemImage: "text.alignleft")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(FuturisticTheme.textSecondary)

              Spacer()

              Text("\(localPrompt.count) characters")
                .font(.system(size: 10))
                .foregroundColor(FuturisticTheme.textTertiary)
            }

            TextEditor(
              text: Binding(
                get: { localPrompt },
                set: { newValue in
                  localPrompt = newValue
                  SettingsManager.shared.updateQuickSlot(
                    number: slot.number, systemPrompt: newValue)
                }
              )
            )
            .font(.system(size: 12, design: .monospaced))
            .foregroundColor(isEnabled ? FuturisticTheme.text : FuturisticTheme.textSecondary)
            .scrollContentBackground(.hidden)
            .padding(12)
            .background(
              RoundedRectangle(cornerRadius: FuturisticTheme.smallCornerRadius)
                .fill(FuturisticTheme.background.opacity(0.5))
            )
            .overlay(
              RoundedRectangle(cornerRadius: FuturisticTheme.smallCornerRadius)
                .stroke(
                  isEnabled ? FuturisticTheme.accent.opacity(0.2) : Color.gray.opacity(0.1),
                  lineWidth: 1
                )
            )
            .frame(height: 120)
            .disabled(!isEnabled)
          }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
        .transition(
          .asymmetric(
            insertion: .opacity.combined(with: .move(edge: .top)),
            removal: .opacity.combined(with: .move(edge: .top))
          ))
      }
    }
    .background(
      RoundedRectangle(cornerRadius: FuturisticTheme.cornerRadius)
        .fill(FuturisticTheme.surface)
        .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
    )
    .overlay(
      RoundedRectangle(cornerRadius: FuturisticTheme.cornerRadius)
        .stroke(
          isEnabled ? FuturisticTheme.accent.opacity(0.15) : Color.gray.opacity(0.1),
          lineWidth: FuturisticTheme.borderWidth
        )
    )
    .animation(.easeInOut(duration: 0.2), value: isEnabled)
    .onAppear {
      localTitle = slot.title
      localSubtitle = slot.subtitle
      localPrompt = slot.systemPrompt
      isEnabled = slot.isEnabled
      // Auto-expand if this is a new/empty slot
      if localTitle.isEmpty && localSubtitle.isEmpty && localPrompt.isEmpty {
        isExpanded = true
      }
    }
    .onChange(of: slot.title) { _, newTitle in
      localTitle = newTitle
    }
    .onChange(of: slot.subtitle) { _, newSubtitle in
      localSubtitle = newSubtitle
    }
    .onChange(of: slot.systemPrompt) { _, newPrompt in
      localPrompt = newPrompt
    }
    .onChange(of: slot.isEnabled) { _, newEnabled in
      isEnabled = newEnabled
    }
  }
}
