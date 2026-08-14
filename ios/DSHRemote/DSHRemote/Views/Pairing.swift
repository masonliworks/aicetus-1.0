// Pairing.swift — dshremote:// scheme URL parsing and QR scanning.
//
// 扫码界面按 UI agent 设计（ScanPairView）：黑底 + accent 取景框 +
// 上下往复扫描线 + 底部文案 + "手动输入"入口；相机层为 AVFoundation。

import SwiftUI
import AVFoundation

/// Parses `dshremote://pair?host=<ip>&port=<port>&token=<token>`.
enum PairingURL {
    static func parse(_ url: URL) -> ServerConfig? {
        guard url.scheme?.lowercased() == "dshremote" else { return nil }
        guard let comps = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let host = comps.queryItems?.first(where: { $0.name == "host" })?.value,
              let token = comps.queryItems?.first(where: { $0.name == "token" })?.value,
              !host.isEmpty, !token.isEmpty else {
            return nil
        }
        let port = Int(comps.queryItems?.first(where: { $0.name == "port" })?.value ?? "") ?? 3878
        return ServerConfig(baseURL: "http://\(host):\(port)", token: token)
    }

    /// Returns true when the scanned string is a pairing URL.
    static func isPairingString(_ s: String) -> Bool {
        s.hasPrefix("dshremote://")
    }
}

// MARK: - 扫码界面（UI agent 设计 + AVFoundation 相机）

struct QRScannerView: View {
    var onScanned: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            ScannerPreview(onScanned: onScanned)
                .ignoresSafeArea()

            // 取景框
            RoundedRectangle(cornerRadius: DSRadius.lg)
                .stroke(DSColor.accent, lineWidth: 3)
                .frame(width: 230, height: 230)
                .overlay(alignment: .top) {
                    // 扫描线（上下往复）
                    TimelineView(.animation) { context in
                        let t = context.date.timeIntervalSinceReferenceDate
                        let y = 25 + abs(sin(t * .pi / 2.2)) * 180
                        Rectangle()
                            .fill(DSColor.accent)
                            .frame(height: 2)
                            .shadow(color: DSColor.accent, radius: 6)
                            .offset(y: y)
                    }
                    .clipped()
                }

            VStack {
                Spacer()
                Text("对准 Mac 伴侣 App 中的二维码")
                    .font(DSFont.body.weight(.semibold))
                Text("识别 dshremote:// 后自动填充地址与 Token\n连接成功时震动反馈")
                    .font(DSFont.footnote)
                    .multilineTextAlignment(.center)
                    .opacity(0.6)
                    .padding(.top, DSSpace.s1)
                Button("无法扫码？手动输入地址与 Token") {
                    dismiss()
                }
                .font(DSFont.footnote)
                .tint(DSColor.accent)
                .padding(.top, DSSpace.s4)
                .padding(.bottom, 40)
            }
            .foregroundStyle(.white)
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("取消") { dismiss() }
                    .tint(DSColor.accent)
            }
        }
    }
}

// MARK: - 相机预览层（AVFoundation，无 UI）

private struct ScannerPreview: UIViewControllerRepresentable {
    var onScanned: (String) -> Void

    func makeUIViewController(context: Context) -> ScannerController {
        let controller = ScannerController()
        controller.onScanned = onScanned
        return controller
    }

    func updateUIViewController(_ controller: ScannerController, context: Context) {}

    final class ScannerController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
        var onScanned: ((String) -> Void)?
        private let session = AVCaptureSession()
        private var settled = false

        override func viewDidLoad() {
            super.viewDidLoad()
            view.backgroundColor = .black
            guard let device = AVCaptureDevice.default(for: .video),
                  let input = try? AVCaptureDeviceInput(device: device),
                  session.canAddInput(input) else { return }
            session.addInput(input)
            let output = AVCaptureMetadataOutput()
            guard session.canAddOutput(output) else { return }
            session.addOutput(output)
            output.setMetadataObjectsDelegate(self, queue: .main)
            output.metadataObjectTypes = [.qr]

            let preview = AVCaptureVideoPreviewLayer(session: session)
            preview.frame = view.layer.bounds
            preview.videoGravity = .resizeAspectFill
            view.layer.addSublayer(preview)

            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.session.startRunning()
            }
        }

        override func viewDidLayoutSubviews() {
            super.viewDidLayoutSubviews()
            (view.layer.sublayers?.first as? AVCaptureVideoPreviewLayer)?.frame = view.layer.bounds
        }

        override func viewWillDisappear(_ animated: Bool) {
            super.viewWillDisappear(animated)
            session.stopRunning()
        }

        func metadataOutput(_ output: AVCaptureMetadataOutput,
                            didOutput metadataObjects: [AVMetadataObject],
                            from connection: AVCaptureConnection) {
            guard !settled,
                  let object = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
                  let value = object.stringValue else { return }
            settled = true
            session.stopRunning()
            AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
            onScanned?(value)
        }
    }
}
