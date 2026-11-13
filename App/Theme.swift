import SwiftUI
import UIKit

enum Theme {
    /// Brand teal for fills and gradients (white text on it stays readable).
    static let ocean = Color(red: 0.02, green: 0.42, blue: 0.52)
    /// Teal for text and outlines: lighter in dark mode so it keeps enough contrast.
    static let accent = adaptive(
        light: UIColor(red: 0.02, green: 0.42, blue: 0.52, alpha: 1),
        dark: UIColor(red: 0.36, green: 0.78, blue: 0.86, alpha: 1)
    )
    static let sunset = Color(red: 0.96, green: 0.52, blue: 0.22)
    /// Mastered categories.
    static let gold = adaptive(
        light: UIColor(red: 0.85, green: 0.60, blue: 0.05, alpha: 1),
        dark: UIColor(red: 1.00, green: 0.80, blue: 0.30, alpha: 1)
    )
    static let success = adaptive(
        light: UIColor(red: 0.16, green: 0.60, blue: 0.36, alpha: 1),
        dark: UIColor(red: 0.30, green: 0.80, blue: 0.50, alpha: 1)
    )
    static let danger = adaptive(
        light: UIColor(red: 0.85, green: 0.25, blue: 0.24, alpha: 1),
        dark: UIColor(red: 1.00, green: 0.45, blue: 0.42, alpha: 1)
    )
    static let heroGradient = LinearGradient(
        colors: [ocean, Color(red: 0.13, green: 0.55, blue: 0.62), sunset],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    private static func adaptive(light: UIColor, dark: UIColor) -> Color {
        Color(uiColor: UIColor { $0.userInterfaceStyle == .dark ? dark : light })
    }
}
