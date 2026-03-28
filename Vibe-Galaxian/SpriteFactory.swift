import SpriteKit

/// Creates pixel-art textures for all game sprites
struct SpriteFactory {

    // MARK: - Pixel Art Helper

    /// Creates a texture from a 2D pixel array. Each pixel is rendered at `scale`x`scale` points.
    static func texture(from pixels: [[NSColor?]], scale: Int = 3) -> SKTexture {
        let pixelW = pixels[0].count
        let pixelH = pixels.count
        let width = pixelW * scale
        let height = pixelH * scale

        let image = NSImage(size: NSSize(width: width, height: height))
        image.lockFocus()
        NSColor.clear.setFill()
        NSBezierPath.fill(NSRect(x: 0, y: 0, width: width, height: height))

        for (row, pixelRow) in pixels.enumerated() {
            for (col, color) in pixelRow.enumerated() {
                if let color = color {
                    color.setFill()
                    let rect = NSRect(
                        x: col * scale,
                        y: (pixelH - 1 - row) * scale,
                        width: scale,
                        height: scale
                    )
                    NSBezierPath.fill(rect)
                }
            }
        }
        image.unlockFocus()

        let tex = SKTexture(image: image)
        tex.filteringMode = .nearest
        return tex
    }

    // MARK: - Color Palette

    static let cyan    = NSColor(red: 0.0, green: 0.9, blue: 1.0, alpha: 1.0)
    static let white   = NSColor.white
    static let blue    = NSColor(red: 0.2, green: 0.4, blue: 1.0, alpha: 1.0)
    static let ltBlue  = NSColor(red: 0.4, green: 0.6, blue: 1.0, alpha: 1.0)
    static let purple  = NSColor(red: 0.7, green: 0.2, blue: 0.8, alpha: 1.0)
    static let ltPurp  = NSColor(red: 0.85, green: 0.4, blue: 0.9, alpha: 1.0)
    static let red     = NSColor(red: 1.0, green: 0.15, blue: 0.15, alpha: 1.0)
    static let ltRed   = NSColor(red: 1.0, green: 0.4, blue: 0.3, alpha: 1.0)
    static let yellow  = NSColor(red: 1.0, green: 0.9, blue: 0.1, alpha: 1.0)
    static let ltYel   = NSColor(red: 1.0, green: 1.0, blue: 0.5, alpha: 1.0)
    static let orange  = NSColor(red: 1.0, green: 0.5, blue: 0.0, alpha: 1.0)

    // MARK: - Player Ship (Galaxip)

    static func playerTexture() -> SKTexture {
        let _ = NSColor.clear
        let C = cyan
        let W = white
        let B = blue

        let pixels: [[NSColor?]] = [
            [nil,nil,nil,nil,nil, W ,nil,nil,nil,nil,nil],
            [nil,nil,nil,nil, C , C , C ,nil,nil,nil,nil],
            [nil,nil,nil, C , C , W , C , C ,nil,nil,nil],
            [nil,nil, C , C , C , C , C , C , C ,nil,nil],
            [nil, C , C , B , C , C , C , B , C , C ,nil],
            [ C , C , C , C , C , C , C , C , C , C , C ],
            [ C , C ,nil, C , C , C , C , C ,nil, C , C ],
            [ C ,nil,nil,nil, C , C , C ,nil,nil,nil, C ],
        ]
        return texture(from: pixels)
    }

    // MARK: - Enemy Sprites

    static func enemyTextures(for type: EnemyType) -> [SKTexture] {
        switch type {
        case .drone:     return [droneFrame1(), droneFrame2()]
        case .emissary:  return [emissaryFrame1(), emissaryFrame2()]
        case .escort:    return [escortFrame1(), escortFrame2()]
        case .flagship:  return [flagshipFrame1(), flagshipFrame2()]
        }
    }

    // Blue Drones
    static func droneFrame1() -> SKTexture {
        let B = blue
        let L = ltBlue

        let pixels: [[NSColor?]] = [
            [nil,nil, B ,nil,nil,nil, B ,nil,nil],
            [nil, B , B , B ,nil, B , B , B ,nil],
            [ B , B , L , B , B , B , L , B , B ],
            [ B ,nil, B , L , L , L , B ,nil, B ],
            [nil,nil,nil, B , B , B ,nil,nil,nil],
            [nil,nil, B ,nil,nil,nil, B ,nil,nil],
        ]
        return texture(from: pixels)
    }

    static func droneFrame2() -> SKTexture {
        let B = blue
        let L = ltBlue

        let pixels: [[NSColor?]] = [
            [nil, B ,nil,nil,nil,nil,nil, B ,nil],
            [ B , B , B ,nil,nil,nil, B , B , B ],
            [ B , B , L , B , B , B , L , B , B ],
            [nil, B , B , L , L , L , B , B ,nil],
            [nil,nil,nil, B , B , B ,nil,nil,nil],
            [nil,nil,nil, B ,nil, B ,nil,nil,nil],
        ]
        return texture(from: pixels)
    }

    // Purple Emissaries
    static func emissaryFrame1() -> SKTexture {
        let P = purple
        let L = ltPurp

        let pixels: [[NSColor?]] = [
            [nil,nil,nil, P , P ,nil,nil,nil],
            [nil, P , P , L , L , P , P ,nil],
            [ P , P , L , L , L , L , P , P ],
            [ P , P , P , L , L , P , P , P ],
            [nil, P ,nil, P , P ,nil, P ,nil],
            [ P ,nil,nil,nil,nil,nil,nil, P ],
        ]
        return texture(from: pixels)
    }

    static func emissaryFrame2() -> SKTexture {
        let P = purple
        let L = ltPurp

        let pixels: [[NSColor?]] = [
            [nil,nil,nil, P , P ,nil,nil,nil],
            [nil, P , P , L , L , P , P ,nil],
            [ P , P , L , L , L , L , P , P ],
            [ P , P , P , L , L , P , P , P ],
            [nil,nil, P , P , P , P ,nil,nil],
            [nil, P ,nil,nil,nil,nil, P ,nil],
        ]
        return texture(from: pixels)
    }

    // Red Escorts
    static func escortFrame1() -> SKTexture {
        let R = red
        let L = ltRed

        let pixels: [[NSColor?]] = [
            [nil, R ,nil,nil,nil,nil, R ,nil],
            [ R , R , R , R , R , R , R , R ],
            [ R , L , R , L , L , R , L , R ],
            [ R , R , L , L , L , L , R , R ],
            [nil, R , R , R , R , R , R ,nil],
            [nil,nil, R ,nil,nil, R ,nil,nil],
            [nil, R ,nil,nil,nil,nil, R ,nil],
        ]
        return texture(from: pixels)
    }

    static func escortFrame2() -> SKTexture {
        let R = red
        let L = ltRed

        let pixels: [[NSColor?]] = [
            [ R ,nil,nil,nil,nil,nil,nil, R ],
            [ R , R , R , R , R , R , R , R ],
            [ R , L , R , L , L , R , L , R ],
            [ R , R , L , L , L , L , R , R ],
            [nil, R , R , R , R , R , R ,nil],
            [nil,nil, R ,nil,nil, R ,nil,nil],
            [nil,nil,nil, R , R ,nil,nil,nil],
        ]
        return texture(from: pixels)
    }

    // Yellow Flagships
    static func flagshipFrame1() -> SKTexture {
        let Y = yellow
        let L = ltYel
        let O = orange

        let pixels: [[NSColor?]] = [
            [nil,nil,nil, Y , Y ,nil,nil,nil,nil,nil],
            [nil,nil, Y , L , L , Y ,nil,nil,nil,nil],
            [nil, Y , Y , L , L , Y , Y ,nil,nil,nil],
            [ Y , Y , L , L , L , L , Y , Y ,nil,nil],
            [ Y , O , Y , L , L , Y , O , Y ,nil,nil],
            [ Y , Y , Y , Y , Y , Y , Y , Y ,nil,nil],
            [nil, Y , Y ,nil,nil, Y , Y ,nil,nil,nil],
            [ Y ,nil,nil,nil,nil,nil,nil, Y ,nil,nil],
        ]
        return texture(from: pixels)
    }

    static func flagshipFrame2() -> SKTexture {
        let Y = yellow
        let L = ltYel
        let O = orange

        let pixels: [[NSColor?]] = [
            [nil,nil,nil, Y , Y ,nil,nil,nil,nil,nil],
            [nil,nil, Y , L , L , Y ,nil,nil,nil,nil],
            [nil, Y , Y , L , L , Y , Y ,nil,nil,nil],
            [ Y , Y , L , L , L , L , Y , Y ,nil,nil],
            [ Y , O , Y , L , L , Y , O , Y ,nil,nil],
            [ Y , Y , Y , Y , Y , Y , Y , Y ,nil,nil],
            [nil,nil, Y , Y , Y , Y ,nil,nil,nil,nil],
            [nil, Y ,nil,nil,nil,nil, Y ,nil,nil,nil],
        ]
        return texture(from: pixels)
    }

    // MARK: - Explosion

    static func explosionTextures() -> [SKTexture] {
        let W = white
        let Y = yellow
        let O = orange
        let R = red

        let frame1: [[NSColor?]] = [
            [nil,nil, W ,nil,nil],
            [nil, W , Y , W ,nil],
            [ W , Y , Y , Y , W ],
            [nil, W , Y , W ,nil],
            [nil,nil, W ,nil,nil],
        ]

        let frame2: [[NSColor?]] = [
            [ W ,nil, Y ,nil, W ],
            [nil, Y , O , Y ,nil],
            [ Y , O , R , O , Y ],
            [nil, Y , O , Y ,nil],
            [ W ,nil, Y ,nil, W ],
        ]

        let frame3: [[NSColor?]] = [
            [ O ,nil,nil,nil, O ],
            [nil,nil, R ,nil,nil],
            [nil, R ,nil, R ,nil],
            [nil,nil, R ,nil,nil],
            [ O ,nil,nil,nil, O ],
        ]

        return [
            texture(from: frame1, scale: 4),
            texture(from: frame2, scale: 5),
            texture(from: frame3, scale: 6),
        ]
    }

    // MARK: - Bullet Texture

    static func playerBulletTexture() -> SKTexture {
        let W = white
        let C = cyan
        let pixels: [[NSColor?]] = [
            [ W ],
            [ C ],
            [ C ],
            [ C ],
        ]
        return texture(from: pixels, scale: 2)
    }

    static func enemyBulletTexture() -> SKTexture {
        let Y = yellow
        let O = orange
        let pixels: [[NSColor?]] = [
            [ Y ],
            [ O ],
            [ O ],
            [ Y ],
        ]
        return texture(from: pixels, scale: 2)
    }
}
