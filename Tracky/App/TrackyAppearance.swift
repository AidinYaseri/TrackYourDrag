import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// UIKit-level chrome that SwiftUI does not expose: the tab bar and navigation
/// bar need to match the app's own dark surfaces rather than the system blur.
enum TrackyAppearance {
    static func apply() {
        #if canImport(UIKit) && !os(watchOS)
        let surface = UIColor(Theme.Palette.surface)
        let base = UIColor(Theme.Palette.base)

        let tabAppearance = UITabBarAppearance()
        tabAppearance.configureWithOpaqueBackground()
        tabAppearance.backgroundColor = surface.withAlphaComponent(0.92)
        tabAppearance.shadowColor = UIColor(Theme.Palette.stroke)
        UITabBar.appearance().standardAppearance = tabAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabAppearance

        let navAppearance = UINavigationBarAppearance()
        navAppearance.configureWithOpaqueBackground()
        navAppearance.backgroundColor = base
        navAppearance.shadowColor = .clear
        navAppearance.titleTextAttributes = [
            .foregroundColor: UIColor(Theme.Palette.textPrimary)
        ]
        navAppearance.largeTitleTextAttributes = [
            .foregroundColor: UIColor(Theme.Palette.textPrimary)
        ]
        UINavigationBar.appearance().standardAppearance = navAppearance
        UINavigationBar.appearance().scrollEdgeAppearance = navAppearance
        UINavigationBar.appearance().compactAppearance = navAppearance
        #endif
    }
}
