//· CurrentSounds ·
// Lo que suena ahora: el pack activo con los ajustes del teclado encima, y los clics del ratón a la
// altura de sus teclas. No toca el motor de audio: AudioEngine le pide los fragmentos y los programa.
// Los packs se leen con el cargador que recibe, y un pack de origen de los ajustes del teclado solo
// se vuelve a leer si hace falta algo que no estaba.

import AVFoundation
import os

struct CurrentSounds {
    private let format: AVAudioFormat
    private let load: (SoundPack) throws -> LoadedPack
    private var pack = LoadedPack()
    /// Lo que suena cada tecla: el pack con los ajustes del teclado encima
    private var keys = KeyboardSounds(pack: LoadedPack(), settings: KeyboardSettings(), sources: [:])
    private var keyboardSettings = KeyboardSettings()
    /// La copia de otro tono de cada sonido, con «Variar el tono» encendido
    private var variants = PitchVariants()
    /// Los packs de los que salen los grupos y las teclas cambiadas, cargados: solo los que se usan,
    /// y de cada uno solo lo que se usa
    private var sources: [String: (use: SourceUse, pack: LoadedPack)] = [:]
    private var mouse = MouseClicks()
    private let log = Logger(subsystem: "com.yestoall.tics", category: "CurrentSounds")

    /// El tono, el volumen y el timbre de cada sonido del ratón: al cambiarlos, se rehacen los clics
    var mouseSettings = MouseSettings() {
        didSet { if mouseSettings != oldValue { matchMouse() } }
    }

    init(format: AVAudioFormat, load: @escaping (SoundPack) throws -> LoadedPack) {
        self.format = format
        self.load = load
    }

    //- Pack activo -

    /// Lee el pack y rehace las teclas y los clics a su altura
    mutating func use(_ soundPack: SoundPack) throws {
        pack = try load(soundPack)
        keys.changePack(to: pack, settings: keyboardSettings, sources: sources.mapValues(\.pack))
        matchVariants()
        matchMouse()
    }

    //- Ajustes del teclado -

    /// Los ajustes del teclado, con la lista de packs de la que salen sus sonidos. Solo se rehace lo
    /// que ha cambiado, y un pack de origen se lee del disco solo si hace falta algo que no estaba
    mutating func use(_ settings: KeyboardSettings, packs: [SoundPack]) {
        keyboardSettings = settings
        var next: [String: (use: SourceUse, pack: LoadedPack)] = [:]
        for (id, use) in settings.sources {
            if let current = sources[id], current.use.contains(use) {
                next[id] = (use, current.use == use ? current.pack : current.pack.only(use))
                continue
            }
            guard let source = packs.first(where: { $0.id == id }) else { continue }
            do {
                next[id] = (use, try load(source).only(use))
            } catch {
                log.error("No se pudo cargar \(source.name, privacy: .public): \(error.localizedDescription, privacy: .public)")
            }
        }
        sources = next
        keys = keys.updated(settings: settings, sources: sources.mapValues(\.pack))
        matchVariants()
    }

    /// Las copias de lo que suena ahora, o ninguna si «Variar el tono» está apagado. Las de los
    /// sonidos que siguen sonando no se recalculan
    private mutating func matchVariants() {
        variants = keyboardSettings.variesPitch ? variants.updated(for: keys.allBuffers) : PitchVariants()
    }

    //- Teclas -

    /// Lo que suena con una pulsación de verdad (ver KeyboardSounds), con sus copias de otro tono
    mutating func sound(for event: KeyEvent) -> KeyboardSounds.Sound? {
        guard let sound = keys.sound(for: event) else { return nil }
        return KeyboardSounds.Sound(variants: variants.expanded(sound.variants), volume: sound.volume)
    }

    /// Una tecla o un atajo, sin pasar por lo que recuerda de las teclas que tienes pulsadas
    func keySounds(for chord: KeyChord, isDown: Bool) -> [AVAudioPCMBuffer] {
        keys.sounds(for: chord, isDown: isDown)
    }

    //- Ratón -

    func clicks(_ button: MouseButton, isDown: Bool) -> [AVAudioPCMBuffer] {
        (isDown ? mouse.down[button] : mouse.up[button]) ?? []
    }

    var dragTicks: [AVAudioPCMBuffer] { mouse.drag }
    var scrollTicks: [AVAudioPCMBuffer] { mouse.scroll }

    /// Pone los clics a la altura de las teclas del pack, que de un pack a otro cambia hasta 13 veces
    private mutating func matchMouse() {
        mouse = MouseSynth.clicks(format: format, keyLoudness: pack.typicalLoudness, settings: mouseSettings)
    }
}
