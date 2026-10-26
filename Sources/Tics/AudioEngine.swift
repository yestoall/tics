//· AudioEngine ·
// Reproduce los fragmentos con AVAudioEngine. Hay 16 reproductores que se turnan:
// al teclear rápido, cada tecla suena en uno distinto y no corta a la anterior.
// Los clics del ratón usan los mismos reproductores. Qué suena con cada cosa lo dice CurrentSounds.

import AVFoundation
import os

@MainActor
final class AudioEngine {
    static let playerCount = 16

    let format: AVAudioFormat

    private let engine = AVAudioEngine()
    private var players: [AVAudioPlayerNode] = []
    private var nextPlayer = 0
    /// Lo que suena ahora: el motor solo lo programa
    private var sounds: CurrentSounds
    /// El tono, el volumen y el timbre de cada sonido del ratón: al cambiarlos, se rehacen los clics
    var mouseSettings: MouseSettings {
        get { sounds.mouseSettings }
        set { sounds.mouseSettings = newValue }
    }
    private var configurationObserver: (any NSObjectProtocol)?
    private let log = Logger(subsystem: "com.yestoall.tics", category: "AudioEngine")

    var volume: Float {
        get { engine.mainMixerNode.outputVolume }
        set { engine.mainMixerNode.outputVolume = newValue }
    }

    init() {
        let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 2)!
        self.format = format
        sounds = CurrentSounds(format: format) { try PackLoader(format: format).load($0) }
        for _ in 0..<Self.playerCount {
            let player = AVAudioPlayerNode()
            engine.attach(player)
            engine.connect(player, to: engine.mainMixerNode, format: format)
            players.append(player)
        }
        engine.prepare()

        // Al cambiar la salida de audio (cascos, AirPods…) macOS para el motor: se arranca otra vez
        configurationObserver = NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange, object: engine, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.outputDidChange() }
        }
    }

    /// Al pararse el motor, los reproductores que ya habían sonado se quedan diciendo que suenan
    /// (`isPlaying`), así que `schedule` no les vuelve a dar `play()` y todo queda mudo hasta
    /// reiniciar la app. Se paran a mano para que el siguiente sonido los arranque
    private func outputDidChange() {
        let sampleRate = engine.outputNode.outputFormat(forBus: 0).sampleRate
        log.info("Cambió la salida de audio (\(sampleRate, privacy: .public) Hz); rearranco el motor")
        for player in players { player.stop() }
        startIfNeeded()
    }

    func load(_ soundPack: SoundPack) throws {
        let started = ContinuousClock.now
        try sounds.use(soundPack)
        log.info("Pack \(soundPack.name, privacy: .public) cargado en \(ContinuousClock.now - started, privacy: .public)")
    }

    func play(_ event: KeyEvent) {
        // Si la tecla tiene variantes, cada pulsación elige una al azar
        guard let sound = sounds.sound(for: event), let buffer = sound.variants.randomElement(),
              schedule(buffer, volume: sound.volume) else { return }
        if !event.isRepeat { logLatency(of: event) }
    }

    //- Ajustes del teclado -

    /// Los ajustes del teclado, con la lista de packs de la que salen sus sonidos. Solo se rehace lo
    /// que ha cambiado, y un pack de origen se lee del disco solo si hace falta algo que no estaba
    func useKeyboardSettings(_ settings: KeyboardSettings, packs: [SoundPack]) {
        sounds.use(settings, packs: packs)
    }

    //- Ratón -

    func playClick(_ button: MouseButton, isDown: Bool) {
        guard let buffer = sounds.clicks(button, isDown: isDown).randomElement() else { return }
        schedule(buffer)
    }

    func playDragTick(volume: Float) {
        guard let buffer = sounds.dragTicks.randomElement() else { return }
        schedule(buffer, volume: volume)
    }

    func playScrollTick() {
        guard let buffer = sounds.scrollTicks.randomElement() else { return }
        schedule(buffer)
    }

    /// Una muestra de un sonido del ratón, en los ajustes: un clic (pulsar y soltar), o unos
    /// cuantos del arrastre o de la rueda, que uno solo no se parece a cómo suenan
    func playSample(_ sound: MouseSound) {
        Task {
            switch sound.button {
            case let button?:
                playClick(button, isDown: true)
                try? await Task.sleep(for: .milliseconds(90))
                playClick(button, isDown: false)
            case nil:
                for _ in 0..<5 {
                    if sound == .drag { playDragTick(volume: 1) } else { playScrollTick() }
                    try? await Task.sleep(for: .milliseconds(sound == .drag ? 70 : 45))
                }
            }
        }
    }

    /// Le da el fragmento al siguiente reproductor del turno
    @discardableResult
    private func schedule(_ buffer: AVAudioPCMBuffer, volume: Float = 1) -> Bool {
        guard startIfNeeded() else { return false }
        let player = players[nextPlayer]
        nextPlayer = (nextPlayer + 1) % players.count
        // Cada reproductor guarda el último volumen: se fija siempre, no solo en las repeticiones
        player.volume = volume
        player.scheduleBuffer(buffer, at: nil, options: .interrupts)
        if !player.isPlaying { player.play() }
        return true
    }

    /// De la tecla al motor de audio, para medir la latencia de la app.
    /// Falta lo que tarda la salida de audio en sonar, que es del sistema
    private func logLatency(of event: KeyEvent) {
        guard event.timestamp > 0 else { return }
        let micros = (clock_gettime_nsec_np(CLOCK_UPTIME_RAW) &- event.timestamp) / 1000
        // En info: macOS no lo guarda en disco, solo lo ve quien escucha el log
        log.info("Latencia hasta el motor: \(micros, privacy: .public) µs")
    }

    /// Una tecla de muestra al elegir pack: la A, pulsada y soltada
    func playPreview() {
        playKeySample(KeyChord(KeyCodes.fallbackKey))
    }

    /// Una tecla o un atajo pulsado y soltado, con lo que suene ahora. No pasa por `play`: no es
    /// una tecla de verdad, y no debe tocar lo que recuerda de las que tienes pulsadas
    func playKeySample(_ chord: KeyChord) {
        func play(isDown: Bool) {
            if let buffer = sounds.keySounds(for: chord, isDown: isDown).randomElement() { schedule(buffer) }
        }
        play(isDown: true)
        Task {
            try? await Task.sleep(for: .milliseconds(90))
            play(isDown: false)
        }
    }

    @discardableResult
    private func startIfNeeded() -> Bool {
        if engine.isRunning { return true }
        do {
            try engine.start()
            return true
        } catch {
            log.error("El motor de audio no arranca: \(error.localizedDescription, privacy: .public)")
            return false
        }
    }
}
