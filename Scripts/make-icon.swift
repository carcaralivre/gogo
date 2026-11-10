// Gera Resources/AppIcon.icns desenhando o ícone do GoGo em código.
// Uso: swift Scripts/make-icon.swift <pasta-de-trabalho> <saida.icns>
import AppKit

let args = CommandLine.arguments
guard args.count >= 3 else {
    FileHandle.standardError.write("uso: make-icon.swift <workdir> <out.icns>\n".data(using: .utf8)!)
    exit(1)
}
let workDir = URL(fileURLWithPath: args[1], isDirectory: true)
let outIcns = URL(fileURLWithPath: args[2])
let iconset = workDir.appendingPathComponent("GoGo.iconset", isDirectory: true)
let fm = FileManager.default
try? fm.removeItem(at: iconset)
try fm.createDirectory(at: iconset, withIntermediateDirectories: true)
try fm.createDirectory(at: outIcns.deletingLastPathComponent(), withIntermediateDirectories: true)

func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor {
    CGColor(red: r / 255, green: g / 255, blue: b / 255, alpha: a)
}

/// Desenha em um canvas lógico de 1024x1024 (origem embaixo-esquerda).
func draw(in ctx: CGContext, pixels: CGFloat) {
    let scale = pixels / 1024
    ctx.scaleBy(x: scale, y: scale)
    ctx.setAllowsAntialiasing(true)
    ctx.interpolationQuality = .high

    // Grade padrão da Apple: forma de 824pt em canvas de 1024pt.
    let shape = CGRect(x: 100, y: 100, width: 824, height: 824)
    let radius = shape.width * 0.2237
    let squircle = CGPath(roundedRect: shape, cornerWidth: radius, cornerHeight: radius, transform: nil)
    let space = CGColorSpaceCreateDeviceRGB()

    // Sombra externa suave.
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -14), blur: 44, color: CGColor(gray: 0, alpha: 0.38))
    ctx.addPath(squircle)
    ctx.setFillColor(rgb(255, 120, 40))
    ctx.fillPath()
    ctx.restoreGState()

    // Fundo: gradiente diagonal laranja -> rosa -> magenta.
    ctx.saveGState()
    ctx.addPath(squircle)
    ctx.clip()
    let base = CGGradient(
        colorsSpace: space,
        colors: [rgb(255, 170, 30), rgb(255, 94, 70), rgb(236, 36, 120), rgb(176, 32, 170)] as CFArray,
        locations: [0, 0.38, 0.72, 1]
    )!
    ctx.drawLinearGradient(base, start: CGPoint(x: 160, y: 960), end: CGPoint(x: 900, y: 120), options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])

    // Brilho no topo (vidro).
    let gloss = CGGradient(
        colorsSpace: space,
        colors: [CGColor(gray: 1, alpha: 0.42), CGColor(gray: 1, alpha: 0.0)] as CFArray,
        locations: [0, 1]
    )!
    ctx.drawRadialGradient(gloss, startCenter: CGPoint(x: 380, y: 1080), startRadius: 0,
                           endCenter: CGPoint(x: 380, y: 1080), endRadius: 760, options: [])

    // Escurecimento sutil embaixo para dar volume.
    let shade = CGGradient(
        colorsSpace: space,
        colors: [CGColor(gray: 0, alpha: 0.0), CGColor(gray: 0, alpha: 0.22)] as CFArray,
        locations: [0, 1]
    )!
    ctx.drawLinearGradient(shade, start: CGPoint(x: 512, y: 520), end: CGPoint(x: 512, y: 100), options: [])

    // Borda interna clara.
    ctx.addPath(CGPath(roundedRect: shape.insetBy(dx: 3, dy: 3), cornerWidth: radius - 3, cornerHeight: radius - 3, transform: nil))
    ctx.setStrokeColor(CGColor(gray: 1, alpha: 0.28))
    ctx.setLineWidth(6)
    ctx.strokePath()
    ctx.restoreGState()

    // Glifo ">>": dois triângulos com cantos arredondados.
    func triangle(x: CGFloat, width: CGFloat, height: CGFloat) -> CGPath {
        let p = CGMutablePath()
        p.move(to: CGPoint(x: x, y: 512 - height / 2))
        p.addLine(to: CGPoint(x: x + width, y: 512))
        p.addLine(to: CGPoint(x: x, y: 512 + height / 2))
        p.closeSubpath()
        return p
    }
    let triW: CGFloat = 236, triH: CGFloat = 356, gap: CGFloat = 46, stroke: CGFloat = 54
    let totalW = 2 * triW + gap + stroke
    let startX = 512 - totalW / 2 + stroke / 2 + 14  // leve ajuste óptico pra direita

    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -12), blur: 28, color: CGColor(gray: 0, alpha: 0.30))
    ctx.beginTransparencyLayer(auxiliaryInfo: nil)
    ctx.setLineJoin(.round)
    ctx.setLineWidth(stroke)
    ctx.setFillColor(CGColor(gray: 1, alpha: 1))
    ctx.setStrokeColor(CGColor(gray: 1, alpha: 1))
    for i in 0..<2 {
        ctx.addPath(triangle(x: startX + CGFloat(i) * (triW + gap), width: triW, height: triH))
        ctx.drawPath(using: .fillStroke)
    }
    // Gradiente sutil só onde o glifo já foi pintado.
    ctx.setBlendMode(.sourceAtop)
    let glyph = CGGradient(
        colorsSpace: space,
        colors: [CGColor(gray: 1, alpha: 0.0), rgb(255, 228, 220, 0.6)] as CFArray,
        locations: [0, 1]
    )!
    ctx.drawLinearGradient(glyph, start: CGPoint(x: 512, y: 720), end: CGPoint(x: 512, y: 300), options: [])
    ctx.endTransparencyLayer()
    ctx.restoreGState()
}

func render(pixels: Int) -> Data {
    let ctx = CGContext(data: nil, width: pixels, height: pixels, bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpaceCreateDeviceRGB(),
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    draw(in: ctx, pixels: CGFloat(pixels))
    let rep = NSBitmapImageRep(cgImage: ctx.makeImage()!)
    return rep.representation(using: .png, properties: [:])!
}

let sizes: [(String, Int)] = [
    ("icon_16x16", 16), ("icon_16x16@2x", 32),
    ("icon_32x32", 32), ("icon_32x32@2x", 64),
    ("icon_128x128", 128), ("icon_128x128@2x", 256),
    ("icon_256x256", 256), ("icon_256x256@2x", 512),
    ("icon_512x512", 512), ("icon_512x512@2x", 1024),
]
for (name, px) in sizes {
    try render(pixels: px).write(to: iconset.appendingPathComponent("\(name).png"))
}
try render(pixels: 1024).write(to: workDir.appendingPathComponent("preview-1024.png"))
try render(pixels: 128).write(to: workDir.appendingPathComponent("preview-128.png"))

let iconutil = Process()
iconutil.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
iconutil.arguments = ["-c", "icns", iconset.path, "-o", outIcns.path]
try iconutil.run()
iconutil.waitUntilExit()
guard iconutil.terminationStatus == 0 else {
    FileHandle.standardError.write("iconutil falhou\n".data(using: .utf8)!)
    exit(1)
}
print("Ícone gerado em \(outIcns.path)")
