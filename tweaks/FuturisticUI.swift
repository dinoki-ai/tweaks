//
//  FuturisticUI.swift
//  tweaks
//
//  Futuristic UI components and styles
//

import SwiftUI

// MARK: - Visual Constants

struct FuturisticTheme {
  // Colors
  static let background = Color(NSColor(red: 0.05, green: 0.05, blue: 0.08, alpha: 1.0))
  static let surface = Color(NSColor(red: 0.10, green: 0.10, blue: 0.15, alpha: 1.0))
  static let surfaceLight = Color(NSColor(red: 0.15, green: 0.15, blue: 0.20, alpha: 1.0))
  static let accent = Color(NSColor(red: 0.4, green: 0.8, blue: 1.0, alpha: 1.0))
  static let accentSecondary = Color(NSColor(red: 0.8, green: 0.4, blue: 1.0, alpha: 1.0))
  static let text = Color.white
  static let textSecondary = Color.white.opacity(0.7)
  static let textTertiary = Color.white.opacity(0.5)
  static let success = Color(NSColor(red: 0.3, green: 0.9, blue: 0.5, alpha: 1.0))
  static let warning = Color(NSColor(red: 1.0, green: 0.8, blue: 0.3, alpha: 1.0))
  static let error = Color(NSColor(red: 1.0, green: 0.3, blue: 0.3, alpha: 1.0))

  // Sizing
  static let cornerRadius: CGFloat = 12
  static let smallCornerRadius: CGFloat = 8
  static let borderWidth: CGFloat = 1
  static let glowRadius: CGFloat = 8
}

// MARK: - View Modifiers

struct GlassEffect: ViewModifier {
  var opacity: Double = 0.1

  func body(content: Content) -> some View {
    content
      .background(
        ZStack {
          FuturisticTheme.surface.opacity(opacity)
          LinearGradient(
            colors: [
              FuturisticTheme.accent.opacity(0.05),
              FuturisticTheme.accentSecondary.opacity(0.05),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
          )
        }
      )
      .overlay(
        RoundedRectangle(cornerRadius: FuturisticTheme.cornerRadius)
          .stroke(
            LinearGradient(
              colors: [
                Color.white.opacity(0.2),
                Color.white.opacity(0.05),
              ],
              startPoint: .topLeading,
              endPoint: .bottomTrailing
            ),
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
      .shadow(color: color.opacity(0.5), radius: radius)
      .shadow(color: color.opacity(0.3), radius: radius * 2)
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
      return isPressed ? FuturisticTheme.accent.opacity(0.8) : FuturisticTheme.accent
    case .secondary:
      return isPressed ? FuturisticTheme.surface.opacity(0.8) : FuturisticTheme.surface
    case .ghost:
      return isHovered ? FuturisticTheme.surface.opacity(0.3) : Color.clear
    }
  }

  private var foregroundColor: Color {
    switch style {
    case .primary:
      return .black
    case .secondary, .ghost:
      return FuturisticTheme.text
    }
  }

  var body: some View {
    Button(action: action) {
      HStack(spacing: 6) {
        if let icon = icon {
          Image(systemName: icon)
            .font(.system(size: 12, weight: .semibold))
        }
        Text(title)
          .font(.system(size: 13, weight: .semibold))
          .lineLimit(1)
          .truncationMode(.tail)
      }
      .foregroundColor(foregroundColor)
      .padding(.horizontal, 16)
      .padding(.vertical, 8)
      .background(backgroundColor)
      .cornerRadius(FuturisticTheme.smallCornerRadius)
      .overlay(
        RoundedRectangle(cornerRadius: FuturisticTheme.smallCornerRadius)
          .stroke(
            style == .ghost ? FuturisticTheme.accent.opacity(0.3) : Color.clear,
            lineWidth: 1
          )
      )
    }
    .buttonStyle(PlainButtonStyle())
    .scaleEffect(isPressed ? 0.95 : 1.0)
    .onHover { hovering in
      withAnimation(.easeInOut(duration: 0.2)) {
        isHovered = hovering
      }
    }
    .onLongPressGesture(
      minimumDuration: 0, maximumDistance: .infinity,
      pressing: { pressing in
        withAnimation(.easeInOut(duration: 0.1)) {
          isPressed = pressing
        }
      }, perform: {})
  }
}

struct FuturisticSegmentedControl: View {
  @Binding var selection: Int
  let options: [String]

  @Namespace private var animation

  var body: some View {
    HStack(spacing: 4) {
      ForEach(Array(options.enumerated()), id: \.offset) { index, option in
        Text(option)
          .font(.system(size: 12, weight: .medium))
          .foregroundColor(selection == index ? .black : FuturisticTheme.textSecondary)
          .padding(.horizontal, 16)
          .padding(.vertical, 6)
          .background(
            ZStack {
              if selection == index {
                FuturisticTheme.accent
                  .cornerRadius(FuturisticTheme.smallCornerRadius)
                  .matchedGeometryEffect(id: "selection", in: animation)
              }
            }
          )
          .onTapGesture {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
              selection = index
            }
          }
      }
    }
    .padding(3)
    .background(FuturisticTheme.surface)
    .cornerRadius(FuturisticTheme.smallCornerRadius + 3)
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
    .font(.system(size: 13))
    .foregroundColor(FuturisticTheme.text)
    .padding(.horizontal, 12)
    .padding(.vertical, 10)
    .background(FuturisticTheme.surface)
    .cornerRadius(FuturisticTheme.smallCornerRadius)
    .overlay(
      RoundedRectangle(cornerRadius: FuturisticTheme.smallCornerRadius)
        .stroke(
          isFocused ? FuturisticTheme.accent : Color.white.opacity(0.1),
          lineWidth: 1
        )
    )
    .focused($isFocused)
  }
}

struct FuturisticCard: View {
  let content: AnyView

  var body: some View {
    content
      .padding()
      .modifier(GlassEffect())
  }
}

// MARK: - Extension helpers

extension View {
  func glassEffect(opacity: Double = 0.1) -> some View {
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
}
