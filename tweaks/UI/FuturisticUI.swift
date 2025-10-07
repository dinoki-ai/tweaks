//
//  FuturisticUI.swift
//  tweaks
//
//  Futuristic minimalist UI components and styles
//

import SwiftUI

// MARK: - Visual Constants

struct FuturisticTheme {
  // Minimalist Color Palette - Using primary accent color only
  static let background = Color(NSColor(red: 0.02, green: 0.02, blue: 0.03, alpha: 1.0))
  static let surface = Color(NSColor(red: 0.08, green: 0.08, blue: 0.10, alpha: 1.0))
  static let surfaceLight = Color(NSColor(red: 0.12, green: 0.12, blue: 0.14, alpha: 1.0))

  // Primary accent color - clean cyan blue
  static let accent = Color(NSColor(red: 0.3, green: 0.7, blue: 0.95, alpha: 1.0))

  // Text hierarchy using opacity
  static let text = Color.white
  static let textSecondary = Color.white.opacity(0.6)
  static let textTertiary = Color.white.opacity(0.4)

  // Semantic colors using accent variations
  static let interactive = accent
  static let interactiveHover = accent.opacity(0.8)
  static let interactiveDisabled = accent.opacity(0.3)

  // Sizing - cleaner, more minimal
  static let cornerRadius: CGFloat = 8
  static let smallCornerRadius: CGFloat = 4
  static let borderWidth: CGFloat = 0.5
  static let glowRadius: CGFloat = 4
}

// MARK: - View Modifiers

struct GlassEffect: ViewModifier {
  var opacity: Double = 0.05

  func body(content: Content) -> some View {
    content
      .background(
        FuturisticTheme.surface.opacity(opacity)
      )
      .overlay(
        RoundedRectangle(cornerRadius: FuturisticTheme.cornerRadius)
          .stroke(
            FuturisticTheme.accent.opacity(0.1),
            lineWidth: FuturisticTheme.borderWidth
          )
      )
      .cornerRadius(FuturisticTheme.cornerRadius)
  }
}

struct NeonGlow: ViewModifier {
  var color: Color = FuturisticTheme.accent
  var radius: CGFloat = FuturisticTheme.glowRadius

  func body(content: Content) -> some View {
    content
      .shadow(color: color.opacity(0.2), radius: radius)
  }
}

// MARK: - Custom Components

struct FuturisticButton: View {
  let title: String
  let icon: String?
  let action: () -> Void
  var style: ButtonStyle = .primary

  enum ButtonStyle {
    case primary, secondary, ghost
  }

  @State private var isHovered = false
  @State private var isPressed = false

  private var backgroundColor: Color {
    switch style {
    case .primary:
      return isPressed
        ? FuturisticTheme.accent.opacity(0.9)
        : isHovered ? FuturisticTheme.accent : FuturisticTheme.accent.opacity(0.95)
    case .secondary:
      return isPressed
        ? FuturisticTheme.surface.opacity(0.5) : isHovered ? FuturisticTheme.surface : Color.clear
    case .ghost:
      return Color.clear
    }
  }

  private var foregroundColor: Color {
    switch style {
    case .primary:
      return FuturisticTheme.background
    case .secondary:
      return isHovered ? FuturisticTheme.text : FuturisticTheme.textSecondary
    case .ghost:
      return isHovered ? FuturisticTheme.accent : FuturisticTheme.textSecondary
    }
  }

  var body: some View {
    Button(action: action) {
      HStack(spacing: 4) {
        if let icon = icon {
          Image(systemName: icon)
            .font(.system(size: 11, weight: .medium))
        }
        Text(title)
          .font(.system(size: 12, weight: .medium))
          .lineLimit(1)
          .truncationMode(.tail)
      }
      .foregroundColor(foregroundColor)
      .padding(.horizontal, 14)
      .padding(.vertical, 7)
      .background(backgroundColor)
      .cornerRadius(FuturisticTheme.smallCornerRadius)
      .overlay(
        RoundedRectangle(cornerRadius: FuturisticTheme.smallCornerRadius)
          .stroke(
            style == .secondary
              ? FuturisticTheme.accent.opacity(isHovered ? 0.3 : 0.1)
              : style == .ghost
                ? FuturisticTheme.accent.opacity(isHovered ? 0.4 : 0.2) : Color.clear,
            lineWidth: FuturisticTheme.borderWidth
          )
      )
    }
    .buttonStyle(PlainButtonStyle())
    .scaleEffect(isPressed ? 0.98 : 1.0)
    .animation(.easeInOut(duration: 0.1), value: isPressed)
    .animation(.easeInOut(duration: 0.15), value: isHovered)
    .onHover { hovering in
      isHovered = hovering
    }
    .onLongPressGesture(
      minimumDuration: 0, maximumDistance: .infinity,
      pressing: { pressing in
        isPressed = pressing
      }, perform: {})
  }
}

struct FuturisticSegmentedControl: View {
  @Binding var selection: Int
  let options: [String]

  @Namespace private var animation

  var body: some View {
    HStack(spacing: 2) {
      ForEach(Array(options.enumerated()), id: \.offset) { index, option in
        Text(option)
          .font(.system(size: 11, weight: .medium))
          .foregroundColor(
            selection == index ? FuturisticTheme.background : FuturisticTheme.textSecondary
          )
          .padding(.horizontal, 12)
          .padding(.vertical, 5)
          .background(
            ZStack {
              if selection == index {
                FuturisticTheme.accent
                  .cornerRadius(FuturisticTheme.smallCornerRadius - 1)
                  .matchedGeometryEffect(id: "selection", in: animation)
              }
            }
          )
          .contentShape(Rectangle())
          .onTapGesture {
            withAnimation(.easeInOut(duration: 0.2)) {
              selection = index
            }
          }
      }
    }
    .padding(2)
    .background(FuturisticTheme.surface.opacity(0.5))
    .overlay(
      RoundedRectangle(cornerRadius: FuturisticTheme.smallCornerRadius + 2)
        .stroke(FuturisticTheme.accent.opacity(0.1), lineWidth: FuturisticTheme.borderWidth)
    )
    .cornerRadius(FuturisticTheme.smallCornerRadius + 2)
  }
}

struct FuturisticTextField: View {
  let placeholder: String
  @Binding var text: String
  var isSecure: Bool = false

  @FocusState private var isFocused: Bool

  var body: some View {
    Group {
      if isSecure {
        SecureField(placeholder, text: $text)
      } else {
        TextField(placeholder, text: $text)
      }
    }
    .textFieldStyle(PlainTextFieldStyle())
    .font(.system(size: 12))
    .foregroundColor(FuturisticTheme.text)
    .padding(.horizontal, 10)
    .padding(.vertical, 8)
    .background(
      FuturisticTheme.surface.opacity(isFocused ? 0.8 : 0.3)
    )
    .cornerRadius(FuturisticTheme.smallCornerRadius)
    .overlay(
      RoundedRectangle(cornerRadius: FuturisticTheme.smallCornerRadius)
        .stroke(
          isFocused ? FuturisticTheme.accent.opacity(0.5) : FuturisticTheme.accent.opacity(0.1),
          lineWidth: FuturisticTheme.borderWidth
        )
    )
    .animation(.easeInOut(duration: 0.15), value: isFocused)
    .focused($isFocused)
  }
}

struct FuturisticCard: View {
  let content: AnyView

  var body: some View {
    content
      .padding(16)
      .modifier(GlassEffect())
  }
}

// MARK: - Extension helpers

extension View {
  func glassEffect(opacity: Double = 0.05) -> some View {
    modifier(GlassEffect(opacity: opacity))
  }

  func neonGlow(color: Color = FuturisticTheme.accent, radius: CGFloat = FuturisticTheme.glowRadius)
    -> some View
  {
    modifier(NeonGlow(color: color, radius: radius))
  }

  func futuristicCard() -> some View {
    FuturisticCard(content: AnyView(self))
  }

  // Additional minimalist helpers
  func minimalistBorder(opacity: Double = 0.1) -> some View {
    self.overlay(
      RoundedRectangle(cornerRadius: FuturisticTheme.cornerRadius)
        .stroke(FuturisticTheme.accent.opacity(opacity), lineWidth: FuturisticTheme.borderWidth)
    )
  }
}
