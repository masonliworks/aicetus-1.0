//
//  MacTheme.swift
//  DSH Remote Mac 伴侣 — 设计 Tokens（macOS 版）
//
//  与 iOS 端 DSTheme.swift 的 token 同名同值（对齐 ui-design-spec v0.3 §4），
//  唯一差异：动态色底层由 UIColor 换成 NSColor。
//  若工程是双端 target，可合并为一份文件用 #if os() 分支。
//

import SwiftUI

// MARK: - Hex / 双模式颜色构造（NSColor 版）

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
        self.init(nsColor: NSColor(name: nil) { appearance in
            let darkMode = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            let hex = darkMode ? dark : light
            return NSColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
                           green: CGFloat((hex >> 8) & 0xFF) / 255,
                           blue: CGFloat(hex & 0xFF) / 255,
                           alpha: opacity)
        })
    }
}

// MARK: - §4.1 颜色（与 iOS DSColor 同名）

enum DSMacColor {
    // 设计稿（dsh-remote-mac.html）用 F5F5F7 作 macOS 窗口底，F0F0F3 作侧边栏底
    static let backgroundBase  = Color(light: 0xF5F5F7, dark: 0x1E1E1E)
    static let sidebar         = Color(light: 0xF0F0F3, dark: 0x262626)
    static let surface         = Color(light: 0xFFFFFF, dark: 0x2A2A2C)
    static let textPrimary     = Color(light: 0x1D1D1F, dark: 0xFFFFFF)
    static let textSecondary   = Color(light: 0x3C3C43, dark: 0xEBEBF5).opacity(0.6)
    static let textTertiary    = Color(light: 0x3C3C43, dark: 0xEBEBF5).opacity(0.35)
    static let divider         = Color(light: 0x000000, dark: 0xFFFFFF).opacity(0.08)

    static let accent          = Color(hex: 0x0A84FF)
    static let statusRunning   = Color(hex: 0x30D158)
    static let statusIdle      = Color(light: 0x8E8E93, dark: 0x98989D)
    static let statusWaiting   = Color(light: 0xFF9F0A, dark: 0xFFD60A)
    static let statusDanger    = Color(light: 0xFF3B30, dark: 0xFF453A)

    /// 语义色文字在 tinted 底上的前景（浅色稍压深保证对比）
    static let runningText     = Color(light: 0x248A3D, dark: 0x30D158)
    static let waitingText     = Color(light: 0xC93400, dark: 0xFFD60A)
}

// MARK: - 字体（沿用 iOS 端尺度；代码用 SF Mono）

enum DSMacFont {
    static let windowTitle = Font.system(size: 22, weight: .bold)
    static let cardHeader  = Font.system(size: 13, weight: .semibold)
    static let body        = Font.system(size: 13)
    static let caption     = Font.system(size: 11)
    static func mono(_ size: CGFloat = 11) -> Font { .system(size: size, design: .monospaced) }
}

// MARK: - 间距 / 圆角（8pt 栅格）

enum DSMacSpace {
    static let s1: CGFloat = 4
    static let s2: CGFloat = 8
    static let s3: CGFloat = 12
    static let s4: CGFloat = 16
    static let s6: CGFloat = 24
}

enum DSMacRadius {
    static let sm: CGFloat = 8
    static let md: CGFloat = 10   // 设计稿卡片 10~12，Mac 侧取 10
    static let lg: CGFloat = 12
}

// MARK: - 通用组件

/// 卡片：白/深灰底 + 0.5pt 描边，无阴影（规范 §4.5 规则）
struct DSMacCard<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        content
            .background(DSMacColor.surface)
            .clipShape(RoundedRectangle(cornerRadius: DSMacRadius.lg))
            .overlay(RoundedRectangle(cornerRadius: DSMacRadius.lg)
                .strokeBorder(DSMacColor.divider, lineWidth: 0.5))
    }
}

/// 状态点（运行中带呼吸脉冲）。
/// 用 TimelineView 驱动透明度：不挂 .animation 修饰符，布局变化时
/// 位置绝不参与动画——灯只在原地呼吸。
struct StatusDot: View {
    let color: Color
    var pulsing: Bool = true

    var body: some View {
        TimelineView(.animation(minimumInterval: 0.05)) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            let phase = t.truncatingRemainder(dividingBy: 1.8) / 1.8
            let opacity = pulsing ? 0.4 + 0.6 * (0.5 - 0.5 * cos(phase * 2 * .pi)) : 1.0
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
                .opacity(opacity)
        }
        .fixedSize()
    }
}

/// 状态 pill（tinted 底 + 语义色文字）
struct StatusPill: View {
    let text: String
    let color: Color
    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(color)
            .padding(.horizontal, 9)
            .padding(.vertical, 2)
            .background(color.opacity(0.14))
            .clipShape(Capsule())
    }
}

/// 卡片标题行（标题 + 右侧附属信息）
struct CardHeader<Trailing: View>: View {
    let title: String
    @ViewBuilder var trailing: Trailing
    init(_ title: String, @ViewBuilder trailing: () -> Trailing = { EmptyView() }) {
        self.title = title
        self.trailing = trailing()
    }
    var body: some View {
        HStack {
            Text(title).font(DSMacFont.cardHeader)
            Spacer()
            trailing
        }
        .padding(.horizontal, 14)
        .padding(.top, 12)
    }
}
