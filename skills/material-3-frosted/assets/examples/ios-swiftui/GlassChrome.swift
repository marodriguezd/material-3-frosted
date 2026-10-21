// SwiftUI — frosted glass chrome.
//
// Copy this into a `Glass` folder in your app; nothing here depends on a
// third-party package.
//
// Three things make SwiftUI different from the Compose and Flutter paths, and
// all three are good news:
//
// 1. `.glassEffect()` exists. On iOS 26+ the system renders its own Liquid
//    Glass material; you do not approximate it. Below 26 you fall back to
//    `Material`, which is the same material the system bars have used for
//    years — a designed fallback, not a scramble.
//
// 2. `GlassEffectContainer` merges nearby glass elements into one optical
//    object. That is the clustering primitive Haze 2.0.1 lacks; here it is a
//    container view.
//
// 3. Reduce Transparency is readable from the environment
//    (`\.accessibilityReduceTransparency`), unlike Flutter where you have to
//    own the setting. Honour it — the system flag exists because users need it.
//
// Availability note: `.glassEffect` and `GlassEffectContainer` are iOS 26 APIs.
// They are behind `if #available` checks with a `Material` fallback, so the same
// view runs from iOS 17 up. Keep the fallback on screen: it is what most users
// will see during the next few years of OS adoption.

import SwiftUI

// MARK: - Tokens

/// How a glass surface looks. Two presets, same as the other platforms.
public struct GlassTokens: Sendable {
    public let cornerRadius: CGFloat
    /// Material used below iOS 26, and whenever the user asked for less
    /// transparency.
    public let material: Material
    /// Tint applied to the native glass (iOS 26) and over the material
    /// fallback. Reduce Transparency uses an opaque system background instead,
    /// so legibility never depends on this tint.
    public let tint: Color

    public init(cornerRadius: CGFloat, material: Material, tint: Color) {
        self.cornerRadius = cornerRadius
        self.material = material
        self.tint = tint
    }

    /// Chrome: bars, the sheet header.
    public static let chrome = GlassTokens(
        cornerRadius: 0,
        material: .bar,
        tint: Color(.systemBackground).opacity(0.001)
    )

    /// Floating objects: control groups, docks.
    public static let floating = GlassTokens(
        cornerRadius: 28,
        material: .regularMaterial,
        tint: Color.white.opacity(0.04)
    )
}

// MARK: - The surface

/// A frosted surface that degrades deliberately.
///
/// The order is: iOS 26 native glass → `Material` → flat colour when the user
/// has Reduce Transparency on. Every branch keeps the same shape and border, so
/// switching between them is a change of texture, not a change of layout.
public struct GlassSurface<Content: View>: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    private let tokens: GlassTokens
    private let isInteractive: Bool
    private let content: Content

    public init(
        tokens: GlassTokens = .chrome,
        isInteractive: Bool = false,
        @ViewBuilder content: () -> Content
    ) {
        self.tokens = tokens
        self.isInteractive = isInteractive
        self.content = content()
    }

    public var body: some View {
        let shape = RoundedRectangle(cornerRadius: tokens.cornerRadius, style: .continuous)

        content
            .background {
                if reduceTransparency {
                    // Designed fallback: an opaque surface in the same hue, with
                    // the same edge. Do not leave a translucent rectangle here.
                    shape.fill(Color(.secondarySystemBackground))
                } else if #available(iOS 26.0, *) {
                    shape
                        .fill(.clear)
                        .glassEffect(
                            isInteractive ? .regular.tint(tokens.tint).interactive() : .regular.tint(tokens.tint),
                            in: shape
                        )
                } else {
                    shape.fill(tokens.material).overlay {
                        shape.fill(tokens.tint)
                    }
                }
            }
            .clipShape(shape)
            .overlay {
                shape.strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
            }
    }
}

// MARK: - Chrome

/// A frosted navigation bar that sits over scrolling content.
///
/// `safeAreaInset` is the part that matters: it inserts the bar into the safe
/// area so the scroll view automatically gets the right content inset, and the
/// content scrolls *under* the bar rather than beside it. Hand-rolling this with
/// a `ZStack` and manual padding is where the "content hidden behind the bar"
/// bugs come from.
public struct GlassNavigationBar: ViewModifier {
    let title: String
    let tokens: GlassTokens

    public func body(content: Content) -> some View {
        content.safeAreaInset(edge: .top, spacing: 0) {
            GlassSurface(tokens: tokens) {
                HStack {
                    Text(title)
                        .font(.title3.weight(.semibold))
                        .lineLimit(1)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
            }
        }
    }
}

/// A frosted tab bar. Top-level destinations only.
public struct GlassTabBar: ViewModifier {
    @Binding var selection: Int
    let items: [String]
    let tokens: GlassTokens

    public func body(content: Content) -> some View {
        content.safeAreaInset(edge: .bottom, spacing: 0) {
            GlassSurface(tokens: tokens) {
                HStack(spacing: 0) {
                    ForEach(items.indices, id: \.self) { index in
                        Button {
                            selection = index
                        } label: {
                            VStack(spacing: 4) {
                                Capsule()
                                    .fill(index == selection ? Color.accentColor : .clear)
                                    .frame(width: 24, height: 3)
                                Text(items[index])
                                    .font(.caption)
                                    .lineLimit(1)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(index == selection ? [.isSelected] : [])
                    }
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 4)
            }
        }
    }
}

/// A group of glass controls that merge into one optical object on iOS 26.
///
/// Below 26 they are separate `Material` panes, which is why the group is capped
/// at a few members: each one is its own blur.
public struct GlassControlGroup<Content: View>: View {
    let spacing: CGFloat
    let tokens: GlassTokens
    let content: Content

    public init(
        spacing: CGFloat = 8,
        tokens: GlassTokens = .floating,
        @ViewBuilder content: () -> Content
    ) {
        self.spacing = spacing
        self.tokens = tokens
        self.content = content()
    }

    public var body: some View {
        if #available(iOS 26.0, *) {
            GlassEffectContainer(spacing: spacing) {
                HStack(spacing: spacing) { content }
            }
        } else {
            GlassSurface(tokens: tokens) {
                HStack(spacing: spacing) { content }
                    .padding(4)
            }
        }
    }
}

// MARK: - Ergonomics

public extension View {
    /// Adds a frosted navigation bar over this view.
    func glassNavigationBar(title: String, tokens: GlassTokens = .chrome) -> some View {
        modifier(GlassNavigationBar(title: title, tokens: tokens))
    }

    /// Adds a frosted tab bar under this view.
    func glassTabBar(selection: Binding<Int>, items: [String], tokens: GlassTokens = .chrome) -> some View {
        modifier(GlassTabBar(selection: selection, items: items, tokens: tokens))
    }
}
