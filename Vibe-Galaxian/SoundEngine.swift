import AVFoundation

/// Synthesizes and plays retro arcade sound effects using AVAudioEngine
class SoundEngine {
    static let shared = SoundEngine()

    private let engine = AVAudioEngine()
    private var players: [AVAudioPlayerNode] = []
    private var nextPlayer = 0
    private let format: AVAudioFormat

    // Pre-generated sound buffers
    private var shootBuffer: AVAudioPCMBuffer!
    private var enemyHitBuffer: AVAudioPCMBuffer!
    private var playerDeathBuffer: AVAudioPCMBuffer!
    private var diveBuffer: AVAudioPCMBuffer!
    private var bonusBuffer: AVAudioPCMBuffer!
    private var waveClearBuffer: AVAudioPCMBuffer!
    private var startBuffer: AVAudioPCMBuffer!
    private var tractorBeamBuffer: AVAudioPCMBuffer!
    private var captureBuffer: AVAudioPCMBuffer!
    private var rescueBuffer: AVAudioPCMBuffer!

    private init() {
        format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!

        // Create a pool of 8 player nodes for polyphonic playback
        for _ in 0..<8 {
            let player = AVAudioPlayerNode()
            engine.attach(player)
            engine.connect(player, to: engine.mainMixerNode, format: format)
            players.append(player)
        }

        engine.mainMixerNode.outputVolume = 0.5

        do {
            try engine.start()
            for p in players { p.play() }
        } catch {
            print("SoundEngine: failed to start – \(error)")
        }

        generateAllBuffers()
    }

    // MARK: - Public API

    func playShoot()        { play(shootBuffer) }
    func playEnemyHit()     { play(enemyHitBuffer) }
    func playPlayerDeath()  { play(playerDeathBuffer) }
    func playDive()         { play(diveBuffer) }
    func playBonus()        { play(bonusBuffer) }
    func playWaveClear()    { play(waveClearBuffer) }
    func playStart()        { play(startBuffer) }
    func playTractorBeam()  { play(tractorBeamBuffer) }
    func playCapture()      { play(captureBuffer) }
    func playRescue()       { play(rescueBuffer) }

    // MARK: - Playback

    private func play(_ buffer: AVAudioPCMBuffer?) {
        guard let buffer = buffer else { return }
        // Round-robin across player nodes for polyphony
        let player = players[nextPlayer]
        nextPlayer = (nextPlayer + 1) % players.count
        player.scheduleBuffer(buffer, completionHandler: nil)
    }

    // MARK: - Sound Synthesis

    private func generateAllBuffers() {
        // Player shoot – short square-wave sweep down
        shootBuffer = makeBuffer(duration: 0.09) { t, p in
            let freq: Float = 1400 - 900 * p
            let amp: Float = 0.22 * (1 - p * p)
            let square: Float = sin(2 * .pi * freq * t) > 0 ? 1 : -1
            return amp * square
        }

        // Enemy hit – noise burst + low thump
        enemyHitBuffer = makeBuffer(duration: 0.18) { t, p in
            let noise = Float.random(in: -1...1)
            let thump = sin(2 * .pi * 90 * t) * (1 - p)
            let amp: Float = 0.3 * pow(1 - p, 1.5)
            return amp * (noise * 0.6 + thump * 0.4)
        }

        // Player death – longer descending noise + tone
        playerDeathBuffer = makeBuffer(duration: 0.55) { t, p in
            let noise = Float.random(in: -1...1)
            let tone = sin(2 * .pi * (500 - 400 * p) * t)
            let amp: Float = 0.35 * pow(1 - p, 1.1)
            return amp * (noise * 0.45 + tone * 0.55)
        }

        // Enemy dive – descending sine swoosh
        diveBuffer = makeBuffer(duration: 0.28) { t, p in
            let freq: Float = 700 - 500 * p
            let amp: Float = 0.12 * (1 - p * 0.4)
            return amp * sin(2 * .pi * freq * t)
        }

        // Bonus – two-note chime (ascending)
        bonusBuffer = makeBuffer(duration: 0.22) { t, p in
            let freq: Float = p < 0.5 ? 880 : 1320
            let amp: Float = 0.2 * (1 - p * 0.7)
            return amp * sin(2 * .pi * freq * t)
        }

        // Wave clear – ascending arpeggio C-E-G-C
        waveClearBuffer = makeBuffer(duration: 0.5) { t, p in
            let freq: Float
            if p < 0.25      { freq = 523 }   // C5
            else if p < 0.5  { freq = 659 }   // E5
            else if p < 0.75 { freq = 784 }   // G5
            else             { freq = 1047 }   // C6
            let amp: Float = 0.22 * (1 - p * 0.4)
            return amp * sin(2 * .pi * freq * t)
        }

        // Start game – quick ascending sweep
        startBuffer = makeBuffer(duration: 0.15) { t, p in
            let freq: Float = 400 + 800 * p
            let amp: Float = 0.18 * (1 - p * 0.5)
            return amp * sin(2 * .pi * freq * t)
        }

        // Tractor beam – warbling sustained tone
        tractorBeamBuffer = makeBuffer(duration: 1.2) { t, p in
            let wobble = sin(2 * .pi * 6 * t)  // 6 Hz wobble
            let freq: Float = 180 + 40 * wobble
            let amp: Float = 0.18
            return amp * sin(2 * .pi * freq * t)
        }

        // Capture – descending ominous sweep
        captureBuffer = makeBuffer(duration: 0.6) { t, p in
            let freq: Float = 600 - 400 * p
            let amp: Float = 0.25 * (1 - p * 0.3)
            let square: Float = sin(2 * .pi * freq * t) > 0 ? 1 : -1
            return amp * square * 0.5 + amp * sin(2 * .pi * freq * 0.5 * t) * 0.5
        }

        // Rescue – triumphant ascending sweep
        rescueBuffer = makeBuffer(duration: 0.4) { t, p in
            let freq: Float
            if p < 0.33      { freq = 440 }
            else if p < 0.66 { freq = 660 }
            else              { freq = 880 }
            let amp: Float = 0.22 * (1 - p * 0.3)
            return amp * sin(2 * .pi * freq * t)
        }
    }

    private func makeBuffer(duration: Float, generator: (Float, Float) -> Float) -> AVAudioPCMBuffer {
        let sampleRate: Float = 44100
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount)!
        buffer.frameLength = frameCount

        let data = buffer.floatChannelData![0]
        let total = Float(frameCount)
        for i in 0..<Int(frameCount) {
            let t = Float(i) / sampleRate        // time in seconds
            let p = Float(i) / total             // progress 0...1
            data[i] = generator(t, p)
        }
        return buffer
    }
}
