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
import CoreImage
import CoreImage.CIFilterBuiltins

struct PairingQRView: View {
    let size: CGFloat
    /// 二维码内容（dshremote://pair?host=...&port=...&token=...）
    let payload: String

    init(size: CGFloat = 140, payload: String = "") {
        self.size = size
        self.payload = payload
    }

    var body: some View {
        Group {
            if let image = qrImage {
                Image(nsImage: image)
                    .resizable()
                    .interpolation(.none)
                    .padding(10)
            } else {
                Image(systemName: "qrcode")
                    .font(.system(size: size * 0.5))
                    .foregroundStyle(DSMacColor.textTertiary)
            }
        }
        .frame(width: size, height: size)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: DSMacRadius.md))
        .overlay(RoundedRectangle(cornerRadius: DSMacRadius.md)
            .strokeBorder(DSMacColor.divider, lineWidth: 0.5))
        .accessibilityLabel("配对二维码")
    }

    /// Real QR via CoreImage (scannable by the iOS app).
    private var qrImage: NSImage? {
        guard !payload.isEmpty, let data = payload.data(using: .utf8) else { return nil }
        let filter = CIFilter.qrCodeGenerator()
        filter.message = data
        filter.correctionLevel = "M"
        guard let ci = filter.outputImage else { return nil }
        let scale = (size - 20) / ci.extent.width
        let transformed = ci.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        let rep = NSCIImageRep(ciImage: transformed)
        let img = NSImage(size: NSSize(width: size, height: size))
        img.addRepresentation(rep)
        return img
    }
}

// MARK: - 配对卡片（概览页与菜单栏复用）

struct PairingCard: View {
    @Environment(BridgeService.self) private var bridge: BridgeService

    var body: some View {
        DSMacCard {
            VStack(spacing: 0) {
                CardHeader("iPhone 配对") {
                    StatusPill(text: "dshremote://", color: DSMacColor.accent)
                }
                Spacer(minLength: 14)
                PairingQRView(size: 150, payload: bridge.pairingDeepLink)
                    .frame(maxWidth: .infinity)
                Spacer(minLength: 14)
                VStack(spacing: 6) {
                    Text(bridge.pairingDeepLink)
                        .font(.system(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundStyle(DSMacColor.accent)
                        .tracking(1.4)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .frame(maxWidth: .infinity)
                    Text("iOS 端「设置 → 扫码配对」\n扫此码自动填充地址与 Token")
                        .font(DSMacFont.caption)
                        .foregroundStyle(DSMacColor.textTertiary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(2)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

#Preview {
    PairingCard()
        .environment(BridgeService())
        .frame(width: 280)
        .padding()
}
