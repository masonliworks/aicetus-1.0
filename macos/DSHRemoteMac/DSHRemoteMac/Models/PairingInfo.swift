// PairingInfo.swift — LAN address discovery, scheme URL, and QR generation.

import Foundation
import CoreImage
import CoreImage.CIFilterBuiltins
import AppKit

struct PairingInfo {
    var host: String
    var port: Int
    var token: String

    /// dshremote://pair?host=<ip>&port=<port>&token=<token>
    var schemeURL: String {
        var comps = URLComponents()
        comps.scheme = "dshremote"
        comps.host = "pair"
        comps.queryItems = [
            URLQueryItem(name: "host", value: host),
            URLQueryItem(name: "port", value: String(port)),
            URLQueryItem(name: "token", value: token),
        ]
        return comps.string ?? ""
    }

    var httpBaseURL: String {
        "http://\(host):\(port)"
    }

    /// Best-effort LAN IPv4 address (prefers en0/en1).
    static func lanIP() -> String? {
        var candidates: [(name: String, addr: String)] = []
        var ifaddrPtr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddrPtr) == 0, let first = ifaddrPtr else { return nil }
        defer { freeifaddrs(ifaddrPtr) }

        var ptr: UnsafeMutablePointer<ifaddrs>? = first
        while let ifa = ptr {
            let name = String(cString: ifa.pointee.ifa_name)
            let flags = Int32(ifa.pointee.ifa_flags)
            let addr = ifa.pointee.ifa_addr
            let isUp = (flags & IFF_UP) == IFF_UP
            let isLoopback = (flags & IFF_LOOPBACK) != 0
            if isUp, !isLoopback, let addr, addr.pointee.sa_family == UInt8(AF_INET) {
                var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                if getnameinfo(addr, socklen_t(addr.pointee.sa_len), &host, socklen_t(host.count), nil, 0, NI_NUMERICHOST) == 0 {
                    candidates.append((name, String(cString: host)))
                }
            }
            ptr = ifa.pointee.ifa_next
        }
        let preferred = ["en0", "en1"]
        for p in preferred {
            if let hit = candidates.first(where: { $0.name == p }) { return hit.addr }
        }
        return candidates.first?.addr
    }

    /// Render the scheme URL as a QR code bitmap (AppKit NSImage).
    func qrImage(scale: CGFloat = 10) -> NSImage? {
        guard let data = schemeURL.data(using: .utf8) else { return nil }
        let filter = CIFilter.qrCodeGenerator()
        filter.message = data
        filter.correctionLevel = "M"
        guard let ciImage = filter.outputImage else { return nil }

        let transformed = ciImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        let rep = NSCIImageRep(ciImage: transformed)
        let image = NSImage(size: rep.size)
        image.addRepresentation(rep)
        return image
    }
}
