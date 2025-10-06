//
//  PromptEditorView.swift
//  tweaks
//
//  Custom system prompt editor with futuristic UI
//

import SwiftUI

struct PromptEditorView: View {
  @ObservedObject var settingsManager = SettingsManager.shared
  @State private var editingPrompt: SystemPrompt?
  @State private var showingNewPrompt = false
  @State private var newPromptName = ""
  @State private var newPromptContent = ""
  @State private var showingEditor = false

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      // Header
      HStack {
        Label("System Prompts", systemImage: "text.bubble")
          .font(.system(size: 14, weight: .semibold))
          .foregroundColor(FuturisticTheme.text)

        Spacer()

        HStack(spacing: 8) {
          FuturisticButton(
            title: "New",
            icon: "plus",
            action: { showingNewPrompt = true },
            style: .ghost
          )
        }
      }

      // Prompts list
      VStack(spacing: 6) {
        ForEach(settingsManager.systemPrompts) { prompt in
          PromptRow(
            prompt: prompt,
            isActive: settingsManager.activePromptId == prompt.id,
            isEditing: showingEditor,
            onSelect: {
              settingsManager.setActivePrompt(prompt.id)
            },
            onEdit: {
              editingPrompt = prompt
            },
            onDelete: {
              settingsManager.deletePrompt(prompt.id)
            }
          )
        }
      }
    }
    .sheet(isPresented: $showingNewPrompt) {
      PromptEditorSheet(
        title: "New Prompt",
        name: $newPromptName,
        content: $newPromptContent,
        onSave: {
          settingsManager.addPrompt(name: newPromptName, content: newPromptContent)
          newPromptName = ""
          newPromptContent = ""
          showingNewPrompt = false
        },
        onCancel: {
          newPromptName = ""
          newPromptContent = ""
          showingNewPrompt = false
        }
      )
    }
    .sheet(item: $editingPrompt) { prompt in
      PromptEditorSheet(
        title: "Edit Prompt",
        name: .constant(prompt.name),
        content: .constant(prompt.content),
        onSave: {
          settingsManager.updatePrompt(
            prompt.id,
            name: prompt.name,
            content: prompt.content
          )
          editingPrompt = nil
        },
        onCancel: {
          editingPrompt = nil
        },
        existingPrompt: prompt
      )
    }
  }
}

struct PromptRow: View {
  let prompt: SystemPrompt
  let isActive: Bool
  let isEditing: Bool
  let onSelect: () -> Void
  let onEdit: () -> Void
  let onDelete: () -> Void

  @State private var isHovered = false

  var body: some View {
    HStack(spacing: 12) {
      // Selection indicator
      Circle()
        .fill(isActive ? FuturisticTheme.accent : Color.clear)
        .frame(width: 8, height: 8)
        .overlay(
          Circle()
            .stroke(
              isActive ? FuturisticTheme.accent : FuturisticTheme.accent.opacity(0.3),
              lineWidth: isActive ? 2 : 1
            )
        )
        .scaleEffect(isActive ? 1.0 : 0.8)
        .animation(.spring(response: 0.3), value: isActive)

      VStack(alignment: .leading, spacing: 2) {
        Text(prompt.name)
          .font(.system(size: 13, weight: isActive ? .semibold : .medium))
          .foregroundColor(isActive ? FuturisticTheme.text : FuturisticTheme.textSecondary)

        if prompt.isDefault {
          Text("Default")
            .font(.system(size: 10))
            .foregroundColor(FuturisticTheme.textTertiary)
        }
      }

      Spacer()

      if (isHovered || isEditing) && !prompt.isDefault {
        HStack(spacing: 8) {
          Button(action: onEdit) {
            Image(systemName: "pencil")
              .font(.system(size: 11))
              .foregroundColor(FuturisticTheme.textSecondary)
          }
          .buttonStyle(PlainButtonStyle())

          Button(action: onDelete) {
            Image(systemName: "trash")
              .font(.system(size: 11))
              .foregroundColor(FuturisticTheme.error.opacity(0.8))
          }
          .buttonStyle(PlainButtonStyle())
        }
        .transition(.opacity.combined(with: .scale))
      }
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 12)
    .background(
      RoundedRectangle(cornerRadius: FuturisticTheme.smallCornerRadius)
        .fill(
          isActive
            ? FuturisticTheme.accent.opacity(0.15)
            : isHovered
              ? FuturisticTheme.surface.opacity(0.8)
              : FuturisticTheme.surface.opacity(0.5)
        )
    )
    .overlay(
      RoundedRectangle(cornerRadius: FuturisticTheme.smallCornerRadius)
        .stroke(
          isActive
            ? FuturisticTheme.accent.opacity(0.5)
            : Color.white.opacity(0.05),
          lineWidth: isActive ? 1.5 : 1
        )
    )
    .scaleEffect(isActive ? 1.02 : 1.0)
    .animation(.spring(response: 0.3), value: isActive)
    .onTapGesture {
      onSelect()
    }
    .onHover { hovering in
      withAnimation(.easeInOut(duration: 0.2)) {
        isHovered = hovering
      }
    }
  }
}

struct PromptEditorSheet: View {
  let title: String
  @Binding var name: String
  @Binding var content: String
  let onSave: () -> Void
  let onCancel: () -> Void
  var existingPrompt: SystemPrompt? = nil

  @State private var editableName: String = ""
  @State private var editableContent: String = ""

  var body: some View {
    VStack(spacing: 20) {
      // Header
      HStack {
        Text(title)
          .font(.system(size: 16, weight: .semibold))
          .foregroundColor(FuturisticTheme.text)

        Spacer()

        Button(action: onCancel) {
          Image(systemName: "xmark")
            .font(.system(size: 12))
            .foregroundColor(FuturisticTheme.textSecondary)
        }
        .buttonStyle(PlainButtonStyle())
      }

      // Form
      VStack(alignment: .leading, spacing: 12) {
        Text("Name")
          .font(.system(size: 12, weight: .medium))
          .foregroundColor(FuturisticTheme.textSecondary)

        FuturisticTextField(
          placeholder: "My Custom Prompt",
          text: $editableName
        )

        Text("System Prompt")
          .font(.system(size: 12, weight: .medium))
          .foregroundColor(FuturisticTheme.textSecondary)

        TextEditor(text: $editableContent)
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
          .frame(height: 150)
      }

      // Actions
      HStack {
        Spacer()

        FuturisticButton(
          title: "Cancel",
          icon: nil,
          action: onCancel,
          style: .ghost
        )

        FuturisticButton(
          title: "Save",
          icon: "checkmark",
          action: {
            if let existing = existingPrompt {
              SettingsManager.shared.updatePrompt(
                existing.id,
                name: editableName,
                content: editableContent
              )
            } else {
              name = editableName
              content = editableContent
            }
            onSave()
          },
          style: .primary
        )
        .disabled(editableName.isEmpty || editableContent.isEmpty)
      }
    }
    .padding(24)
    .frame(width: 400, height: 350)
    .background(FuturisticTheme.background)
    .onAppear {
      if let existing = existingPrompt {
        editableName = existing.name
        editableContent = existing.content
      } else {
        editableName = name
        editableContent = content
      }
    }
  }
}
