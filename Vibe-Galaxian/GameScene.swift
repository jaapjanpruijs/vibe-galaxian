import SpriteKit
import GameController

// MARK: - Physics Categories

struct PhysicsCategory {
    static let none:         UInt32 = 0
    static let player:       UInt32 = 0x1 << 0
    static let playerBullet: UInt32 = 0x1 << 1
    static let enemy:        UInt32 = 0x1 << 2
    static let enemyBullet:  UInt32 = 0x1 << 3
}

// MARK: - Enemy Type

enum EnemyType: Int {
    case drone = 0
    case emissary = 1
    case escort = 2
    case flagship = 3

    var pointsInFormation: Int {
        switch self {
        case .drone:     return 30
        case .emissary:  return 40
        case .escort:    return 50
        case .flagship:  return 60
        }
    }

    var pointsDiving: Int {
        switch self {
        case .drone:     return 60
        case .emissary:  return 80
        case .escort:    return 100
        case .flagship:  return 150
        }
    }
}

// MARK: - Enemy Node

class EnemyNode: SKSpriteNode {
    var enemyType: EnemyType = .drone
    var gridRow: Int = 0
    var gridCol: Int = 0
    var formationOffset: CGPoint = .zero
    var isDiving: Bool = false
    var isReturning: Bool = false
    var animFrames: [SKTexture] = []
    var hasFiredDuringDive: Int = 0
    var hasCapturedShip: Bool = false  // for flagships holding a captured player ship
}

// MARK: - Game Scene

class GameScene: SKScene, SKPhysicsContactDelegate {

    // MARK: - Constants

    let sceneW: CGFloat = 480
    let sceneH: CGFloat = 640

    let playerSpeed: CGFloat = 220
    let playerBulletSpeed: CGFloat = 450
    let enemyBulletSpeed: CGFloat = 220

    let formationSwaySpeed: CGFloat = 30
    let gridSpacingX: CGFloat = 38
    let gridSpacingY: CGFloat = 30
    let formationBaseY: CGFloat = 460
    let dualOffset: CGFloat = 18

    // MARK: - Properties

    // Player
    var player: SKSpriteNode!
    var playerBulletsOnScreen: Int = 0
    let maxPlayerBullets: Int = 3
    var fireCooldown: TimeInterval = 0
    let fireCooldownTime: TimeInterval = 0.15
    var isPlayerDead = false
    var respawnTimer: TimeInterval = 0

    // Dual fighter
    var isDualFighter = false
    var dualPartner: SKSpriteNode?

    // Tractor beam / capture
    var capturedShipNode: SKSpriteNode?   // the ship sitting in formation
    var capturingFlagship: EnemyNode?     // which flagship holds it
    var isBeingCaptured = false
    var tractorBeamFlagship: EnemyNode?   // active during beam
    var tractorBeamNode: SKNode?

    // Enemies
    var enemies: [EnemyNode] = []
    var formationX: CGFloat = 240
    var formationDir: CGFloat = 1.0

    // Game state
    var score: Int = 0
    var highScore: Int = 0
    var lives: Int = 3
    var wave: Int = 1
    var isGameOver: Bool = false
    var waveTransition: Bool = false

    // Input
    var keysPressed = Set<UInt16>()
    var gamepadStickX: CGFloat = 0

    // UI
    var scoreLabel: SKLabelNode!
    var highScoreLabel: SKLabelNode!
    var livesNodes: [SKSpriteNode] = []
    var waveLabel: SKLabelNode!
    var gameOverLabel: SKLabelNode?
    var startLabel: SKLabelNode?

    // Timing
    var lastUpdateTime: TimeInterval = 0
    var diveAccumulator: TimeInterval = 0
    var nextDiveInterval: TimeInterval = 2.5

    // Stars
    var stars: [SKShapeNode] = []

    // Textures
    var explosionFrames: [SKTexture] = []
    var playerBulletTex: SKTexture!
    var enemyBulletTex: SKTexture!

    // Sound
    let sound = SoundEngine.shared

    // MARK: - Scene Setup

    override func didMove(to view: SKView) {
        backgroundColor = .black

        physicsWorld.gravity = .zero
        physicsWorld.contactDelegate = self

        explosionFrames = SpriteFactory.explosionTextures()
        playerBulletTex = SpriteFactory.playerBulletTexture()
        enemyBulletTex = SpriteFactory.enemyBulletTexture()

        setupStarfield()
        setupUI()
        setupPlayer()
        setupFormation()
        randomizeDiveInterval()
        setupGamepad()

        showStartMessage()
    }

    // MARK: - Starfield

    func setupStarfield() {
        for _ in 0..<80 {
            let star = SKShapeNode(circleOfRadius: CGFloat.random(in: 0.5...1.5))
            let brightness = CGFloat.random(in: 0.3...1.0)
            let colors: [NSColor] = [.white, .cyan,
                NSColor(red: 1, green: 1, blue: 0.8, alpha: 1),
                NSColor(red: 0.8, green: 0.8, blue: 1, alpha: 1)]
            star.fillColor = colors.randomElement()!.withAlphaComponent(brightness)
            star.strokeColor = .clear
            star.position = CGPoint(
                x: CGFloat.random(in: 0...sceneW),
                y: CGFloat.random(in: 0...sceneH)
            )
            star.zPosition = -10
            let speed = CGFloat.random(in: 15...60)
            star.userData = NSMutableDictionary()
            star.userData!["speed"] = speed
            addChild(star)
            stars.append(star)
        }
    }

    func updateStarfield(_ dt: CGFloat) {
        for star in stars {
            let speed = (star.userData?["speed"] as? CGFloat) ?? 30
            star.position.y -= speed * dt
            if star.position.y < -2 {
                star.position.y = sceneH + 2
                star.position.x = CGFloat.random(in: 0...sceneW)
            }
        }
    }

    // MARK: - UI

    func setupUI() {
        scoreLabel = makeLabel("SCORE  0", size: 15, color: .white)
        scoreLabel.position = CGPoint(x: 10, y: sceneH - 22)
        scoreLabel.horizontalAlignmentMode = .left
        addChild(scoreLabel)

        highScoreLabel = makeLabel("HIGH SCORE  0", size: 15, color: .red)
        highScoreLabel.position = CGPoint(x: sceneW / 2, y: sceneH - 22)
        highScoreLabel.horizontalAlignmentMode = .center
        addChild(highScoreLabel)

        waveLabel = makeLabel("STAGE 1", size: 13, color: .yellow)
        waveLabel.position = CGPoint(x: sceneW - 10, y: 8)
        waveLabel.horizontalAlignmentMode = .right
        addChild(waveLabel)

        updateLivesDisplay()
    }

    func makeLabel(_ text: String, size: CGFloat, color: NSColor) -> SKLabelNode {
        let label = SKLabelNode(fontNamed: "Menlo-Bold")
        label.text = text
        label.fontSize = size
        label.fontColor = color
        label.zPosition = 100
        return label
    }

    func updateScore(_ points: Int) {
        score += points
        if score > highScore { highScore = score }
        scoreLabel.text = "SCORE  \(score)"
        highScoreLabel.text = "HIGH SCORE  \(highScore)"
    }

    func updateLivesDisplay() {
        for n in livesNodes { n.removeFromParent() }
        livesNodes.removeAll()

        let tex = SpriteFactory.playerTexture()
        for i in 0..<max(0, lives - 1) {
            let icon = SKSpriteNode(texture: tex)
            icon.setScale(0.5)
            icon.position = CGPoint(x: 18 + CGFloat(i) * 22, y: 10)
            icon.zPosition = 100
            addChild(icon)
            livesNodes.append(icon)
        }
    }

    func showStartMessage() {
        let label = makeLabel("PRESS SPACE OR \u{24B6} TO START", size: 16, color: .cyan)
        label.position = CGPoint(x: sceneW / 2, y: sceneH / 2 - 40)
        label.name = "startLabel"
        let blink = SKAction.sequence([
            SKAction.fadeAlpha(to: 0.2, duration: 0.5),
            SKAction.fadeAlpha(to: 1.0, duration: 0.5)
        ])
        label.run(SKAction.repeatForever(blink))
        addChild(label)
        startLabel = label
    }

    // MARK: - Player

    func setupPlayer() {
        let tex = SpriteFactory.playerTexture()
        player = SKSpriteNode(texture: tex)
        player.position = CGPoint(x: sceneW / 2, y: 50)
        player.zPosition = 10

        player.physicsBody = SKPhysicsBody(rectangleOf: CGSize(width: 22, height: 16))
        player.physicsBody?.categoryBitMask = PhysicsCategory.player
        player.physicsBody?.contactTestBitMask = PhysicsCategory.enemy | PhysicsCategory.enemyBullet
        player.physicsBody?.collisionBitMask = PhysicsCategory.none
        player.physicsBody?.isDynamic = true

        addChild(player)
    }

    func enableDualFighter() {
        guard !isDualFighter else { return }
        isDualFighter = true

        let tex = SpriteFactory.playerTexture()
        let partner = SKSpriteNode(texture: tex)
        partner.zPosition = 10
        partner.position = CGPoint(x: player.position.x + dualOffset * 2, y: player.position.y)
        addChild(partner)
        dualPartner = partner

        // Widen player hitbox
        player.physicsBody = SKPhysicsBody(rectangleOf: CGSize(width: 22 + dualOffset * 2, height: 16))
        player.physicsBody?.categoryBitMask = PhysicsCategory.player
        player.physicsBody?.contactTestBitMask = PhysicsCategory.enemy | PhysicsCategory.enemyBullet
        player.physicsBody?.collisionBitMask = PhysicsCategory.none
        player.physicsBody?.isDynamic = true
    }

    func disableDualFighter() {
        guard isDualFighter else { return }
        isDualFighter = false

        if let partner = dualPartner {
            showExplosion(at: partner.position)
            partner.removeFromParent()
        }
        dualPartner = nil

        // Restore normal hitbox
        player.physicsBody = SKPhysicsBody(rectangleOf: CGSize(width: 22, height: 16))
        player.physicsBody?.categoryBitMask = PhysicsCategory.player
        player.physicsBody?.contactTestBitMask = PhysicsCategory.enemy | PhysicsCategory.enemyBullet
        player.physicsBody?.collisionBitMask = PhysicsCategory.none
        player.physicsBody?.isDynamic = true
    }

    // MARK: - Formation

    func setupFormation() {
        for e in enemies { e.removeFromParent() }
        enemies.removeAll()
        formationX = sceneW / 2

        let layout: [(row: Int, type: EnemyType, cols: [Int])] = [
            (0, .drone,    [0,1,2,3,4,5,6,7,8,9]),
            (1, .drone,    [0,1,2,3,4,5,6,7,8,9]),
            (2, .drone,    [0,1,2,3,4,5,6,7,8,9]),
            (3, .emissary, [1,2,3,4,5,6,7,8]),
            (4, .escort,   [2,3,4,5,6,7]),
            (5, .flagship, [3,6]),
        ]

        for def in layout {
            for col in def.cols {
                let enemy = createEnemy(type: def.type)
                enemy.gridRow = def.row
                enemy.gridCol = col

                let offsetX = (CGFloat(col) - 4.5) * gridSpacingX
                let offsetY = CGFloat(def.row) * gridSpacingY
                enemy.formationOffset = CGPoint(x: offsetX, y: offsetY)
                enemy.position = CGPoint(
                    x: formationX + offsetX,
                    y: formationBaseY + offsetY
                )

                addChild(enemy)
                enemies.append(enemy)

                if enemy.animFrames.count >= 2 {
                    let animate = SKAction.animate(with: enemy.animFrames, timePerFrame: 0.4)
                    enemy.run(SKAction.repeatForever(animate), withKey: "wingFlap")
                }
            }
        }
    }

    func createEnemy(type: EnemyType) -> EnemyNode {
        let textures = SpriteFactory.enemyTextures(for: type)
        let enemy = EnemyNode(texture: textures.first)
        enemy.enemyType = type
        enemy.animFrames = textures
        enemy.zPosition = 5
        enemy.name = "enemy"

        let bodySize: CGSize
        switch type {
        case .flagship: bodySize = CGSize(width: 24, height: 18)
        default:        bodySize = CGSize(width: 22, height: 16)
        }

        enemy.physicsBody = SKPhysicsBody(rectangleOf: bodySize)
        enemy.physicsBody?.categoryBitMask = PhysicsCategory.enemy
        enemy.physicsBody?.contactTestBitMask = PhysicsCategory.playerBullet
        enemy.physicsBody?.collisionBitMask = PhysicsCategory.none
        enemy.physicsBody?.isDynamic = true

        return enemy
    }

    // MARK: - Keyboard Input

    override func keyDown(with event: NSEvent) {
        guard !event.isARepeat else { return }
        keysPressed.insert(event.keyCode)

        if event.keyCode == 49 { handleFireOrStart() }
        if event.keyCode == 3 { view?.window?.toggleFullScreen(nil) }
    }

    override func keyUp(with event: NSEvent) {
        keysPressed.remove(event.keyCode)
    }

    func handleFireOrStart() {
        if isGameOver {
            restartGame()
        } else if startLabel != nil {
            startLabel?.removeFromParent()
            startLabel = nil
            sound.playStart()
        } else {
            firePlayerBullet()
        }
    }

    // MARK: - Gamepad Input

    func setupGamepad() {
        NotificationCenter.default.addObserver(
            forName: .GCControllerDidConnect, object: nil, queue: .main
        ) { [weak self] note in
            if let c = note.object as? GCController { self?.configureController(c) }
        }
        for c in GCController.controllers() { configureController(c) }
        GCController.startWirelessControllerDiscovery()
    }

    func configureController(_ controller: GCController) {
        if let gp = controller.extendedGamepad { configureExtendedGamepad(gp) }
        else if let gp = controller.microGamepad { configureMicroGamepad(gp) }
    }

    func configureExtendedGamepad(_ gp: GCExtendedGamepad) {
        gp.dpad.left.pressedChangedHandler = { [weak self] _, _, p in
            if p { self?.keysPressed.insert(123) } else { self?.keysPressed.remove(123) }
        }
        gp.dpad.right.pressedChangedHandler = { [weak self] _, _, p in
            if p { self?.keysPressed.insert(124) } else { self?.keysPressed.remove(124) }
        }
        gp.leftThumbstick.xAxis.valueChangedHandler = { [weak self] _, v in
            self?.gamepadStickX = CGFloat(v)
        }
        gp.buttonA.pressedChangedHandler = { [weak self] _, _, p in if p { self?.handleFireOrStart() } }
        gp.buttonB.pressedChangedHandler = { [weak self] _, _, p in if p { self?.handleFireOrStart() } }
        gp.rightTrigger.pressedChangedHandler = { [weak self] _, _, p in if p { self?.handleFireOrStart() } }
        gp.buttonMenu.pressedChangedHandler = { [weak self] _, _, p in if p { self?.handleFireOrStart() } }
    }

    func configureMicroGamepad(_ gp: GCMicroGamepad) {
        gp.dpad.xAxis.valueChangedHandler = { [weak self] _, v in self?.gamepadStickX = CGFloat(v) }
        gp.buttonA.pressedChangedHandler = { [weak self] _, _, p in if p { self?.handleFireOrStart() } }
    }

    // MARK: - Shooting

    func firePlayerBullet() {
        guard playerBulletsOnScreen < maxPlayerBullets,
              fireCooldown <= 0,
              !isPlayerDead, !isBeingCaptured, !isGameOver else { return }

        // Fire from main ship
        spawnBullet(at: CGPoint(x: player.position.x, y: player.position.y + 18))

        // Fire from dual partner too
        if isDualFighter, let partner = dualPartner {
            spawnBullet(at: CGPoint(x: partner.position.x, y: partner.position.y + 18))
        }

        fireCooldown = fireCooldownTime
        sound.playShoot()
    }

    func spawnBullet(at position: CGPoint) {
        let bullet = SKSpriteNode(texture: playerBulletTex)
        bullet.position = position
        bullet.zPosition = 8
        bullet.name = "playerBullet"

        bullet.physicsBody = SKPhysicsBody(rectangleOf: CGSize(width: 3, height: 10))
        bullet.physicsBody?.categoryBitMask = PhysicsCategory.playerBullet
        bullet.physicsBody?.contactTestBitMask = PhysicsCategory.enemy
        bullet.physicsBody?.collisionBitMask = PhysicsCategory.none
        bullet.physicsBody?.isDynamic = true

        addChild(bullet)
        playerBulletsOnScreen += 1

        let dist = sceneH - bullet.position.y + 10
        let duration = TimeInterval(dist / playerBulletSpeed)

        bullet.run(SKAction.sequence([
            SKAction.moveBy(x: 0, y: dist, duration: duration),
            SKAction.run { [weak self] in
                bullet.removeFromParent()
                self?.playerBulletsOnScreen -= 1
            }
        ]))
    }

    func fireEnemyBullet(from position: CGPoint) {
        guard !isPlayerDead, !isBeingCaptured else { return }

        let bullet = SKSpriteNode(texture: enemyBulletTex)
        bullet.position = position
        bullet.zPosition = 8
        bullet.name = "enemyBullet"

        bullet.physicsBody = SKPhysicsBody(rectangleOf: CGSize(width: 3, height: 10))
        bullet.physicsBody?.categoryBitMask = PhysicsCategory.enemyBullet
        bullet.physicsBody?.contactTestBitMask = PhysicsCategory.player
        bullet.physicsBody?.collisionBitMask = PhysicsCategory.none
        bullet.physicsBody?.isDynamic = true

        addChild(bullet)

        let dx = player.position.x - position.x
        let dy = player.position.y - position.y
        let dist = sqrt(dx * dx + dy * dy)
        let spread = CGFloat.random(in: -20...20)
        let nx = (dx + spread) / max(dist, 1)
        let ny = dy / max(dist, 1)

        let travel: CGFloat = 700
        let speed = enemyBulletSpeed + CGFloat(wave) * 8
        let duration = TimeInterval(travel / speed)

        bullet.run(SKAction.sequence([
            SKAction.moveBy(x: nx * travel, y: ny * travel, duration: duration),
            SKAction.removeFromParent()
        ]))
    }

    // MARK: - Enemy Diving

    func randomizeDiveInterval() {
        let base = max(0.6, 2.5 - Double(wave) * 0.2)
        nextDiveInterval = TimeInterval.random(in: base...(base + 1.5))
    }

    func triggerDive() {
        let candidates = enemies.filter { !$0.isDiving && !$0.isReturning }
        guard let chosen = candidates.randomElement() else { return }

        if chosen.enemyType == .flagship {
            startFlagshipDive(chosen)
        } else {
            startSoloDive(chosen)
        }
    }

    func startFlagshipDive(_ flagship: EnemyNode) {
        // 30% chance of tractor beam dive if: no captured ship yet, not dual fighter,
        // player has lives to spare, and we're past wave 1
        let canCapture = capturingFlagship == nil && !isDualFighter && lives > 1
        if canCapture {
            startTractorBeamDive(flagship)
            return
        }

        let escorts = enemies.filter {
            $0.enemyType == .escort && !$0.isDiving && !$0.isReturning &&
            abs($0.gridCol - flagship.gridCol) <= 2
        }.prefix(2)

        startSoloDive(flagship)

        for (i, escort) in escorts.enumerated() {
            let delay = 0.25 * Double(i + 1)
            run(SKAction.sequence([
                SKAction.wait(forDuration: delay),
                SKAction.run { [weak self] in self?.startSoloDive(escort) }
            ]))
        }
    }

    func startSoloDive(_ enemy: EnemyNode) {
        enemy.isDiving = true
        enemy.hasFiredDuringDive = 0
        enemy.removeAction(forKey: "wingFlap")

        sound.playDive()

        let start = enemy.position
        let goLeft = start.x > sceneW / 2

        let path = CGMutablePath()
        path.move(to: start)

        let curve1X = start.x + (goLeft ? -100 : 100)
        let curve1Y = start.y - 60

        path.addQuadCurve(
            to: CGPoint(x: start.x + (goLeft ? -50 : 50), y: start.y - 140),
            control: CGPoint(x: curve1X, y: curve1Y)
        )

        let targetX = player.position.x + CGFloat.random(in: -60...60)
        path.addQuadCurve(
            to: CGPoint(x: targetX, y: -30),
            control: CGPoint(x: goLeft ? 20 : sceneW - 20, y: 200)
        )

        let diveSpeed: CGFloat = 160 + CGFloat(wave) * 12
        let duration = TimeInterval(700 / diveSpeed)

        let followPath = SKAction.follow(path, asOffset: false, orientToPath: false, duration: duration)

        let fireSequence = SKAction.sequence([
            SKAction.wait(forDuration: duration * 0.25),
            SKAction.run { [weak self] in
                guard enemy.parent != nil else { return }
                self?.fireEnemyBullet(from: enemy.position)
            },
            SKAction.wait(forDuration: duration * 0.3),
            SKAction.run { [weak self] in
                guard enemy.parent != nil else { return }
                self?.fireEnemyBullet(from: enemy.position)
            }
        ])

        enemy.run(SKAction.sequence([
            SKAction.group([followPath, fireSequence]),
            SKAction.run { [weak self] in self?.enemyFinishedDive(enemy) }
        ]), withKey: "dive")
    }

    func enemyFinishedDive(_ enemy: EnemyNode) {
        guard enemy.parent != nil, enemies.contains(where: { $0 === enemy }) else { return }

        enemy.isReturning = true
        enemy.position = CGPoint(
            x: CGFloat.random(in: 60...(sceneW - 60)),
            y: sceneH + 30
        )

        let targetX = formationX + enemy.formationOffset.x
        let targetY = formationBaseY + enemy.formationOffset.y

        enemy.run(SKAction.sequence([
            SKAction.move(to: CGPoint(x: targetX, y: targetY), duration: 1.2),
            SKAction.run {
                enemy.isDiving = false
                enemy.isReturning = false
                if enemy.animFrames.count >= 2 {
                    let anim = SKAction.animate(with: enemy.animFrames, timePerFrame: 0.4)
                    enemy.run(SKAction.repeatForever(anim), withKey: "wingFlap")
                }
            }
        ]), withKey: "return")
    }

    // MARK: - Tractor Beam & Capture

    func startTractorBeamDive(_ flagship: EnemyNode) {
        flagship.isDiving = true
        flagship.removeAction(forKey: "wingFlap")
        sound.playDive()

        let start = flagship.position
        let hoverX = player.position.x + CGFloat.random(in: -30...30)
        let hoverY: CGFloat = 160

        // Dive to hover position above player
        let path = CGMutablePath()
        path.move(to: start)
        path.addQuadCurve(
            to: CGPoint(x: hoverX, y: hoverY),
            control: CGPoint(x: start.x, y: 300)
        )

        let duration: TimeInterval = 1.2

        flagship.run(SKAction.sequence([
            SKAction.follow(path, asOffset: false, orientToPath: false, duration: duration),
            SKAction.run { [weak self] in
                self?.activateTractorBeam(from: flagship)
            }
        ]), withKey: "dive")
    }

    func activateTractorBeam(from flagship: EnemyNode) {
        guard !isPlayerDead, !isGameOver, !isBeingCaptured else {
            enemyFinishedDive(flagship)
            return
        }

        tractorBeamFlagship = flagship
        sound.playTractorBeam()

        // Create beam visual - expanding horizontal lines
        let beam = SKNode()
        beam.name = "tractorBeam"
        beam.zPosition = 15
        for i in 0..<10 {
            let y = -CGFloat(i) * 12 - 12
            let width: CGFloat = 8 + CGFloat(i) * 6
            let line = SKShapeNode(rectOf: CGSize(width: width, height: 2))
            line.fillColor = NSColor(red: 0.3, green: 0.6, blue: 1.0, alpha: 0.8)
            line.strokeColor = .clear
            line.position = CGPoint(x: 0, y: y)
            beam.addChild(line)
        }
        // Add a glow overlay
        let glow = SKShapeNode(rectOf: CGSize(width: 12, height: 120))
        glow.fillColor = NSColor(red: 0.5, green: 0.8, blue: 1.0, alpha: 0.15)
        glow.strokeColor = .clear
        glow.position = CGPoint(x: 0, y: -65)
        beam.addChild(glow)

        beam.position = CGPoint(x: flagship.position.x, y: flagship.position.y)
        addChild(beam)
        tractorBeamNode = beam

        // Pulse the beam
        let pulse = SKAction.sequence([
            SKAction.fadeAlpha(to: 0.4, duration: 0.12),
            SKAction.fadeAlpha(to: 1.0, duration: 0.12)
        ])
        beam.run(SKAction.repeatForever(pulse), withKey: "pulse")

        // Beam lasts 2 seconds, then flagship retreats
        flagship.run(SKAction.sequence([
            SKAction.wait(forDuration: 2.0),
            SKAction.run { [weak self] in
                self?.deactivateTractorBeam()
                if self?.isBeingCaptured == false {
                    self?.enemyFinishedDive(flagship)
                }
            }
        ]), withKey: "beamTimer")
    }

    func deactivateTractorBeam() {
        tractorBeamFlagship = nil
        tractorBeamNode?.removeAllActions()
        tractorBeamNode?.removeFromParent()
        tractorBeamNode = nil
    }

    func checkTractorBeamCapture() {
        guard let flagship = tractorBeamFlagship, !isBeingCaptured, !isPlayerDead else { return }

        let beamX = flagship.position.x
        let beamWidth: CGFloat = 50
        let playerX = player.position.x

        if abs(playerX - beamX) < beamWidth / 2 {
            capturePlayerShip(by: flagship)
        }
    }

    func capturePlayerShip(by flagship: EnemyNode) {
        isBeingCaptured = true
        sound.playCapture()

        // Cancel beam timer
        flagship.removeAction(forKey: "beamTimer")

        // If dual fighter, lose the partner instead of the main ship
        if isDualFighter {
            disableDualFighter()
            isBeingCaptured = false
            deactivateTractorBeam()
            enemyFinishedDive(flagship)
            return
        }

        // Animate player floating up into the beam
        let targetY = flagship.position.y - 20
        player.run(SKAction.sequence([
            SKAction.move(to: CGPoint(x: flagship.position.x, y: targetY), duration: 1.0),
            SKAction.run { [weak self] in
                guard let self = self else { return }

                // Hide original player
                self.player.isHidden = true

                // Create captured ship node that will sit in formation
                let capturedShip = SKSpriteNode(texture: SpriteFactory.playerTexture())
                capturedShip.zPosition = 6
                capturedShip.name = "capturedShip"
                // Position it relative to flagship's formation offset
                capturedShip.position = flagship.position
                self.addChild(capturedShip)
                self.capturedShipNode = capturedShip
                self.capturingFlagship = flagship
                flagship.hasCapturedShip = true

                self.deactivateTractorBeam()

                // Flagship returns to formation carrying the captured ship
                self.isBeingCaptured = false
                self.enemyFinishedDive(flagship)

                // Lose a life
                self.lives -= 1
                self.updateLivesDisplay()
                self.isPlayerDead = true

                if self.lives <= 0 {
                    self.gameOver()
                } else {
                    self.respawnTimer = 2.0
                }
            }
        ]))
    }

    func releaseCapturedShip() {
        guard let capturedShip = capturedShipNode else { return }

        capturingFlagship?.hasCapturedShip = false
        capturingFlagship = nil

        sound.playRescue()

        // Animate captured ship flying down to dock with player
        let targetX = player.position.x + dualOffset
        let targetY = player.position.y

        capturedShip.run(SKAction.sequence([
            // Little spin
            SKAction.group([
                SKAction.rotate(byAngle: .pi * 4, duration: 0.8),
                SKAction.move(to: CGPoint(x: targetX, y: targetY + 80), duration: 0.8)
            ]),
            // Dock with player
            SKAction.group([
                SKAction.rotate(toAngle: 0, duration: 0.4),
                SKAction.move(to: CGPoint(x: targetX, y: targetY), duration: 0.4)
            ]),
            SKAction.run { [weak self] in
                capturedShip.removeFromParent()
                self?.capturedShipNode = nil
                self?.enableDualFighter()
            }
        ]))
    }

    // MARK: - Collisions

    func didBegin(_ contact: SKPhysicsContact) {
        let collision = contact.bodyA.categoryBitMask | contact.bodyB.categoryBitMask

        if collision == PhysicsCategory.playerBullet | PhysicsCategory.enemy {
            let bulletNode = (contact.bodyA.categoryBitMask == PhysicsCategory.playerBullet)
                ? contact.bodyA.node : contact.bodyB.node
            let enemyNode = (contact.bodyA.categoryBitMask == PhysicsCategory.enemy)
                ? contact.bodyA.node : contact.bodyB.node

            if let bullet = bulletNode as? SKSpriteNode,
               let enemy = enemyNode as? EnemyNode {
                handleBulletHitEnemy(bullet: bullet, enemy: enemy)
            }
        }

        if collision == PhysicsCategory.player | PhysicsCategory.enemyBullet {
            let otherNode = (contact.bodyA.categoryBitMask == PhysicsCategory.player)
                ? contact.bodyB.node : contact.bodyA.node
            otherNode?.removeFromParent()
            handlePlayerHit()
        }

        if collision == PhysicsCategory.player | PhysicsCategory.enemy {
            let enemyNode = (contact.bodyA.categoryBitMask == PhysicsCategory.enemy)
                ? contact.bodyA.node : contact.bodyB.node
            if let enemy = enemyNode as? EnemyNode {
                enemies.removeAll { $0 === enemy }
                enemy.removeFromParent()
            }
            handlePlayerHit()
        }
    }

    func handleBulletHitEnemy(bullet: SKSpriteNode, enemy: EnemyNode) {
        bullet.removeFromParent()
        playerBulletsOnScreen -= 1

        var points = enemy.isDiving ? enemy.enemyType.pointsDiving : enemy.enemyType.pointsInFormation

        if enemy.enemyType == .flagship && enemy.isDiving {
            let remainingEscorts = enemies.filter { $0.enemyType == .escort && $0.isDiving }
            if remainingEscorts.isEmpty {
                points = 800
                sound.playBonus()
            }
        }

        updateScore(points)
        showScorePopup(points, at: enemy.position)
        showExplosion(at: enemy.position)
        sound.playEnemyHit()

        // Check if this flagship had a captured ship
        let hadCapturedShip = enemy.hasCapturedShip && capturingFlagship === enemy

        enemy.removeAllActions()
        enemy.removeFromParent()
        enemies.removeAll { $0 === enemy }

        // If this was the tractor beam flagship, cancel the beam
        if tractorBeamFlagship === enemy {
            deactivateTractorBeam()
        }

        // Release captured ship if this flagship held it
        if hadCapturedShip && !isPlayerDead {
            releaseCapturedShip()
        } else if hadCapturedShip && isPlayerDead {
            // Ship is lost - remove the captured ship node
            capturedShipNode?.removeFromParent()
            capturedShipNode = nil
            capturingFlagship = nil
        }
    }

    func handlePlayerHit() {
        guard !isPlayerDead, !isGameOver, !isBeingCaptured else { return }

        // If dual fighter, lose the partner instead of dying
        if isDualFighter {
            disableDualFighter()
            sound.playEnemyHit()
            return
        }

        isPlayerDead = true

        showExplosion(at: player.position)
        sound.playPlayerDeath()
        player.isHidden = true

        lives -= 1
        updateLivesDisplay()

        if lives <= 0 {
            gameOver()
        } else {
            respawnTimer = 2.0
        }
    }

    // MARK: - Effects

    func showExplosion(at position: CGPoint) {
        guard !explosionFrames.isEmpty else { return }

        let explosion = SKSpriteNode(texture: explosionFrames[0])
        explosion.position = position
        explosion.zPosition = 20

        addChild(explosion)

        let anim = SKAction.animate(with: explosionFrames, timePerFrame: 0.12)
        explosion.run(SKAction.sequence([
            anim,
            SKAction.fadeOut(withDuration: 0.1),
            SKAction.removeFromParent()
        ]))
    }

    func showScorePopup(_ points: Int, at position: CGPoint) {
        let label = makeLabel("\(points)", size: 12,
                              color: points >= 800 ? .yellow : .white)
        label.position = position
        label.zPosition = 25
        addChild(label)

        label.run(SKAction.sequence([
            SKAction.group([
                SKAction.moveBy(x: 0, y: 30, duration: 0.6),
                SKAction.fadeOut(withDuration: 0.6)
            ]),
            SKAction.removeFromParent()
        ]))
    }

    // MARK: - Wave Management

    func nextWave() {
        guard !waveTransition else { return }
        waveTransition = true

        wave += 1
        waveLabel.text = "STAGE \(wave)"
        sound.playWaveClear()

        let announcement = makeLabel("STAGE \(wave)", size: 24, color: .yellow)
        announcement.position = CGPoint(x: sceneW / 2, y: sceneH / 2)
        addChild(announcement)

        announcement.run(SKAction.sequence([
            SKAction.wait(forDuration: 1.5),
            SKAction.fadeOut(withDuration: 0.5),
            SKAction.removeFromParent()
        ]))

        enumerateChildNodes(withName: "enemyBullet") { node, _ in node.removeFromParent() }
        enumerateChildNodes(withName: "playerBullet") { node, _ in node.removeFromParent() }
        playerBulletsOnScreen = 0

        // If captured ship's flagship was cleared with the wave, the ship is lost
        if let cap = capturingFlagship, !enemies.contains(where: { $0 === cap }) {
            capturedShipNode?.removeFromParent()
            capturedShipNode = nil
            capturingFlagship = nil
        }

        run(SKAction.sequence([
            SKAction.wait(forDuration: 2.0),
            SKAction.run { [weak self] in
                self?.setupFormation()
                self?.waveTransition = false
                self?.randomizeDiveInterval()
            }
        ]))
    }

    // MARK: - Game Over / Restart

    func gameOver() {
        isGameOver = true
        removeAction(forKey: "diveTimer")
        deactivateTractorBeam()

        let label = makeLabel("GAME OVER", size: 28, color: .red)
        label.position = CGPoint(x: sceneW / 2, y: sceneH / 2 + 20)
        addChild(label)
        gameOverLabel = label

        let restartLabel = makeLabel("PRESS SPACE TO PLAY AGAIN", size: 14, color: .white)
        restartLabel.position = CGPoint(x: sceneW / 2, y: sceneH / 2 - 20)
        restartLabel.name = "restartLabel"
        let blink = SKAction.sequence([
            SKAction.fadeAlpha(to: 0.2, duration: 0.5),
            SKAction.fadeAlpha(to: 1.0, duration: 0.5)
        ])
        restartLabel.run(SKAction.repeatForever(blink))
        addChild(restartLabel)
    }

    func restartGame() {
        removeAllChildren()
        removeAllActions()

        stars.removeAll()
        enemies.removeAll()
        livesNodes.removeAll()
        playerBulletsOnScreen = 0
        fireCooldown = 0
        gameOverLabel = nil
        startLabel = nil
        gamepadStickX = 0
        isDualFighter = false
        dualPartner = nil
        capturedShipNode = nil
        capturingFlagship = nil
        isBeingCaptured = false
        tractorBeamFlagship = nil
        tractorBeamNode = nil

        score = 0
        lives = 6
        wave = 1
        isGameOver = false
        isPlayerDead = false
        waveTransition = false
        lastUpdateTime = 0
        diveAccumulator = 0

        setupStarfield()
        setupUI()
        setupPlayer()
        setupFormation()
        randomizeDiveInterval()

        sound.playStart()
    }

    // MARK: - Update Loop

    override func update(_ currentTime: TimeInterval) {
        if lastUpdateTime == 0 { lastUpdateTime = currentTime }
        let dt = min(currentTime - lastUpdateTime, 1.0 / 30.0)
        lastUpdateTime = currentTime

        updateStarfield(CGFloat(dt))

        guard !isGameOver, startLabel == nil else { return }

        // Check tractor beam capture
        checkTractorBeamCapture()

        if isPlayerDead {
            respawnTimer -= dt
            if respawnTimer <= 0 {
                isPlayerDead = false
                player.position = CGPoint(x: sceneW / 2, y: 50)
                player.isHidden = false
            }
            return
        }

        if isBeingCaptured { return }

        if fireCooldown > 0 { fireCooldown -= dt }
        updatePlayerMovement(CGFloat(dt))
        updateFormation(CGFloat(dt))

        if !waveTransition {
            diveAccumulator += dt
            if diveAccumulator >= nextDiveInterval {
                diveAccumulator = 0
                triggerDive()
                randomizeDiveInterval()
            }

            if CGFloat.random(in: 0...1) < CGFloat(dt) * (0.3 + CGFloat(wave) * 0.08) {
                let inFormation = enemies.filter { !$0.isDiving && !$0.isReturning }
                if let shooter = inFormation.randomElement() {
                    fireEnemyBullet(from: CGPoint(x: shooter.position.x,
                                                   y: shooter.position.y - 10))
                }
            }
        }

        if enemies.isEmpty && !waveTransition {
            nextWave()
        }
    }

    func updatePlayerMovement(_ dt: CGFloat) {
        var moveX: CGFloat = 0

        if keysPressed.contains(123) { moveX -= 1 }
        if keysPressed.contains(124) { moveX += 1 }
        if abs(gamepadStickX) > 0.15 { moveX += gamepadStickX }
        moveX = max(-1, min(1, moveX))

        player.position.x += moveX * playerSpeed * dt

        let halfW: CGFloat = isDualFighter ? 16 + dualOffset : 16
        player.position.x = max(halfW, min(sceneW - halfW, player.position.x))

        // Keep dual partner in sync
        if let partner = dualPartner {
            partner.position = CGPoint(
                x: player.position.x + dualOffset * 2,
                y: player.position.y
            )
        }
    }

    func updateFormation(_ dt: CGFloat) {
        let speed = (formationSwaySpeed + CGFloat(wave) * 2) * dt
        formationX += speed * formationDir

        var minCol = 10
        var maxCol = -1
        for e in enemies where !e.isDiving && !e.isReturning {
            minCol = min(minCol, e.gridCol)
            maxCol = max(maxCol, e.gridCol)
        }

        if maxCol >= 0 {
            let leftEdge = formationX + (CGFloat(minCol) - 4.5) * gridSpacingX
            let rightEdge = formationX + (CGFloat(maxCol) - 4.5) * gridSpacingX

            if rightEdge > sceneW - 20 {
                formationDir = -1
                formationX = sceneW - 20 - (CGFloat(maxCol) - 4.5) * gridSpacingX
            } else if leftEdge < 20 {
                formationDir = 1
                formationX = 20 - (CGFloat(minCol) - 4.5) * gridSpacingX
            }
        }

        for enemy in enemies where !enemy.isDiving && !enemy.isReturning {
            enemy.position.x = formationX + enemy.formationOffset.x
            enemy.position.y = formationBaseY + enemy.formationOffset.y
        }

        // Keep captured ship next to its flagship in formation
        if let ship = capturedShipNode, let flagship = capturingFlagship,
           !flagship.isDiving, !flagship.isReturning {
            ship.position = CGPoint(
                x: flagship.position.x + gridSpacingX * 0.6,
                y: flagship.position.y
            )
        }

        // Move beam visual with flagship during beam
        if let beam = tractorBeamNode, let flagship = tractorBeamFlagship {
            beam.position = CGPoint(x: flagship.position.x, y: flagship.position.y)
        }
    }
}
