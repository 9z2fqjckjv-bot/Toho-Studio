import SwiftUI
import AppKit

public struct AppLogoView: View {
    public let size: CGFloat
    public let cornerRadius: CGFloat

    public static let logoPath = "/Volumes/ZSSD/GitHub/repository/TohoStudio/Documents/動画用/手作り素材/AI生成/image11.png"

    public init(size: CGFloat = 28, cornerRadius: CGFloat = 6) {
        self.size = size
        self.cornerRadius = cornerRadius
    }

    public var body: some View {
        Group {
            if let nsImage = resizedImage {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: size, height: size)
                    .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                    .shadow(color: Color.black.opacity(0.2), radius: 2, x: 0, y: 1)
            } else {
                // Fallback icon
                ZStack {
                    LinearGradient(
                        colors: [Color.green.opacity(0.8), Color.blue.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    Image(systemName: "sparkles")
                        .foregroundColor(.white)
                        .font(.system(size: size * 0.5))
                }
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
            }
        }
    }

    private var resizedImage: NSImage? {
        guard let original = NSImage(contentsOfFile: AppLogoView.logoPath) else { return nil }
        let targetSize = NSSize(width: size, height: size)
        let newImg = NSImage(size: targetSize)
        newImg.lockFocus()
        original.draw(in: NSRect(origin: .zero, size: targetSize),
                      from: NSRect(origin: .zero, size: original.size),
                      operation: .copy,
                      fraction: 1.0)
        newImg.unlockFocus()
        return newImg
    }
}
