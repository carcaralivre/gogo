import AppKit

/// Ícone ">>" (fast-forward) desenhado em código, como template para seguir dark/light.
enum MenuBarIcon {
    static func make() -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: false) { _ in
            NSColor.black.set()
            for x in [CGFloat(1.5), CGFloat(8.5)] {
                let path = NSBezierPath()
                path.move(to: NSPoint(x: x, y: 4.5))
                path.line(to: NSPoint(x: x + 7, y: 9))
                path.line(to: NSPoint(x: x, y: 13.5))
                path.close()
                path.lineJoinStyle = .round
                path.lineWidth = 1.6
                path.fill()
                path.stroke()
            }
            return true
        }
        image.isTemplate = true
        return image
    }
}
