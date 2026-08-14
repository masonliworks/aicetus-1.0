//
//  PairingQRView.swift
//  DSH Remote Mac 伴侣 — 配对二维码
//
//  当前为装饰性假码（固定种子伪随机 + 三个定位角），
//  与 HTML 设计稿的 JS 生成逻辑同构。
//  真实实现：把 `dshremote://host:port?token=…` 串交给
//  CoreImage 的 CIQRCodeGenerator 替换 `cellAt` 的取值即可。
//

import SwiftUI

struct PairingQRView: View {
    let size: CGFloat
    /// 模块矩阵边长（设计稿为 12×12）
    private let dim = 12

    init(size: CGFloat = 140) { self.size = size }

    // 固定种子 LCG，保证每次渲染一致
    private static func seeded() -> [Bool] {
        var seed: UInt64 = 42
        var out = [Bool]()
        out.reserveCapacity(12 * 12)
        for _ in 0..<(12 * 12) {
            seed = (seed &* 16807) % 2147483647
            out.append(Double(seed) / 2147483647 < 0.42)
        }
        return out
    }
    private static let cells = seeded()

    private func isFinder(_ r: Int, _ c: Int) -> Bool {
        (r < 4 && c < 4) || (r < 4 && c > 7) || (r > 7 && c < 4)
    }

    private func cellAt(_ r: Int, _ c: Int) -> Bool {
        if isFinder(r, c) {
            let lr = r % 4, lc = c % 4
            return lr == 0 || lr == 3 || lc == 0 || lc == 3 || (lr > 0 && lr < 3 && lc > 0 && lc < 3)
        }
        return Self.cells[r * dim + c]
    }

    var body: some View {
        Canvas { ctx, canvasSize in
            let inset: CGFloat = 9
            let gap: CGFloat = 1
            let cell = (min(canvasSize.width, canvasSize.height) - inset * 2 + gap) / CGFloat(dim) - gap
            for r in 0..<dim {
                for c in 0..<dim where cellAt(r, c) {
                    let rect = CGRect(x: inset + CGFloat(c) * (cell + gap),
                                      y: inset + CGFloat(r) * (cell + gap),
                                      width: cell, height: cell)
                    ctx.fill(Path(roundedRect: rect, cornerRadius: 1),
                             with: .color(Color(light: 0x1D1D1F, dark: 0xFFFFFF)))
                }
            }
        }
        .frame(width: size, height: size)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: DSMacRadius.md))
        .overlay(RoundedRectangle(cornerRadius: DSMacRadius.md)
            .strokeBorder(DSMacColor.divider, lineWidth: 0.5))
        .accessibilityLabel("配对二维码")
    }
}

// MARK: - 配对卡片（概览页与菜单栏复用）

struct PairingCard: View {
    @EnvironmentObject var bridge: BridgeService

    var body: some View {
        DSMacCard {
            VStack(spacing: 0) {
                CardHeader("iPhone 配对") {
                    StatusPill(text: "dshremote://", color: DSMacColor.accent)
                }
                PairingQRView()
                    .padding(.top, 12)
                Text(bridge.pairingDeepLink)
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundStyle(DSMacColor.accent)
                    .tracking(1.4)
                    .padding(.top, 8)
                Text("iOS 端「设置 → 扫码配对」\n扫此码自动填充地址与 Token")
                    .font(DSMacFont.caption)
                    .foregroundStyle(DSMacColor.textTertiary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                    .padding(.top, 4)
                    .padding(.bottom, 13)
            }
        }
    }
}

#Preview {
    PairingCard()
        .environmentObject(BridgeService())
        .frame(width: 280)
        .padding()
}
