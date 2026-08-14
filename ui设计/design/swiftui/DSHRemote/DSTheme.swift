//
//  DSTheme.swift
//  DSH Remote — 设计 Tokens（对齐 ui-design-spec v0.3 §4）
//
//  命名与规范文档一一对应，改规范时同步改这里。
//

import SwiftUI

// MARK: - Hex / 双模式颜色构造

extension Color {
    init(hex: UInt, opacity: Double = 1.0) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: opacity)
    }

    /// 浅色/深色双模式动态色
    init(light: UInt, dark: UInt, opacity: Double = 1.0) {
        self.init(uiColor: UIColor { traits in
            let hex = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: CGFloat((hex >> 16) & 0xFF) / 255,
                           green: CGFloat((hex >> 8) & 0xFF) / 255,
                           blue: CGFloat(hex & 0xFF) / 255,
                           alpha: opacity)
        })
    }
}

// MARK: - §4.1 颜色（语义色，深浅各一套）

enum DSColor {
    static let backgroundBase  = Color(light: 0xF2F2F7, dark: 0x000000)   // background.base
    static let surface         = Color(light: 0xFFFFFF, dark: 0x1C1C1E)   // surface
    static let surfaceRaised   = Color(light: 0xFFFFFF, dark: 0x2C2C2E)   // surface.raised
    static let textPrimary     = Color(light: 0x000000, dark: 0xFFFFFF)   // text.primary
    static let textSecondary   = Color(light: 0x3C3C43, dark: 0xEBEBF5).opacity(0.6)
    static let textTertiary    = Color(light: 0x3C3C43, dark: 0xEBEBF5).opacity(0.3)
    static let divider         = Color(light: 0x3C3C43, dark: 0x545458).opacity(0.2)

    static let accent          = Color(hex: 0x0A84FF)                     // accent
    static let statusRunning   = Color(hex: 0x30D158)                     // status.running
    static let statusIdle      = Color(light: 0x8E8E93, dark: 0x98989D)   // status.idle
    static let statusWaiting   = Color(light: 0xFF9F0A, dark: 0xFFD60A)   // status.waiting
    static let statusDanger    = Color(light: 0xFF3B30, dark: 0xFF453A)   // status.danger
    static let statusComplete  = Color(light: 0x007AFF, dark: 0x0A84FF)   // status.complete

    /// 待审批卡片底（waiting 10%，§4.1 规则）
    static let waitingSurface  = Color(light: 0xFF9F0A, dark: 0xFFD60A).opacity(0.10)
}

// MARK: - §4.2 字体（系统字体，代码用 SF Mono）

enum DSFont {
    static let title       = Font.system(size: 17, weight: .semibold)
    static let headline    = Font.system(size: 17, weight: .semibold)
    static let body        = Font.system(size: 15)
    static let subheadline = Font.system(size: 15)
    static let footnote    = Font.system(size: 13)
    static let caption     = Font.system(size: 12)
    static let caption2    = Font.system(size: 11)
    static func mono(_ size: CGFloat = 13) -> Font { .system(size: size, design: .monospaced) }
}

// MARK: - §4.3 间距（8pt 栅格）

enum DSSpace {
    static let s1: CGFloat = 4
    static let s2: CGFloat = 8
    static let s3: CGFloat = 12
    static let s4: CGFloat = 16
    static let s5: CGFloat = 20
    static let page: CGFloat = 16   // 页面左右留白
}

// MARK: - §4.4 圆角

enum DSRadius {
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let pill: CGFloat = 999
}

// MARK: - §4.5 通用修饰

/// .bar 材质横栏（横幅 / 审批条 / 队列区 / 信息栏 / 输入栏）
struct BarMaterial: ViewModifier {
    func body(content: Content) -> some View {
        content.background(.bar)
    }
}
extension View {
    func barMaterial() -> some View { modifier(BarMaterial()) }
}
