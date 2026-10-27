//· KeyboardSounds ·
// Lo que suena cada tecla: el pack activo con los ajustes del teclado encima. Manda lo más
// concreto: el atajo cambiado, luego la tecla, luego el grupo de teclas y luego el pack. Se rehace
// al cambiar de pack (`changePack`), como los clics del ratón; al cambiar de ajustes, solo lo que ha
// cambiado (`updated`). Con cada pulsación dice qué suena y a qué volumen (`sound(for:)`).

import AVFoundation

struct KeyboardSounds {
    /// Lo que suena con una pulsación: una de sus variantes, al azar, a este volumen
    struct Sound {
        let variants: [AVAudioPCMBuffer]
        let volume: Float
    }

    /// El volumen de las repeticiones al mantener una tecla pulsada: hasta 30 por segundo a todo
    /// volumen serían una ráfaga
    static let repeatVolume: Float = 0.4

    /// Lo que suena encima del pack, con los ajustes de los que sale: si no cambian, no se rehace
    private struct Layer<Recipe: Equatable, Sounds> {
        let recipe: Recipe
        let sounds: Sounds
    }

    /// Lo que hace sonar una tecla cambiada
    private struct KeyRecipe: Equatable {
        let changed: ChangedKey
        /// Una tecla «Del pack» parte de lo que suena debajo de ella: esto, si está cambiado
        let base: Base?
    }

    /// Lo que hay debajo de una tecla: un atajo tiene su tecla sola, y una tecla, su grupo
    private indirect enum Base: Equatable {
        case group(ChangedGroup)
        case key(KeyRecipe)
    }

    /// Lo que suena al pulsar y al soltar una tecla cambiada
    private struct Sounds {
        let down: [AVAudioPCMBuffer]
        let up: [AVAudioPCMBuffer]

        func callAsFunction(isDown: Bool) -> [AVAudioPCMBuffer] { isDown ? down : up }
    }

    private let pack: LoadedPack
    /// Lo que suena una tecla típica de cada grupo de teclas del pack activo, la altura de los grupos
    /// y las teclas cambiadas. Medirlo recorre el grupo entero: se mide la primera vez que hace falta
    private var groupLoudness: [KeyGroup: Float] = [:]
    private var groups: [KeyGroup: Layer<ChangedGroup, LoadedPack>] = [:]
    private var keys: [KeyChord: Layer<KeyRecipe, Sounds>] = [:]
    /// Con qué se pulsó cada tecla que sigue abajo
    private var pressed: [UInt16: KeyChord] = [:]

    /// `sources` son los packs de origen, ya cargados, por id. Una tecla o un grupo cuyo pack no
    /// está entre ellos sigue sonando como si no estuviera cambiado
    init(pack: LoadedPack, settings: KeyboardSettings, sources: [String: LoadedPack]) {
        self.pack = pack
        build(settings, sources: sources, reusing: nil)
    }

    /// Todo otra vez sobre otro pack. Las teclas que siguen abajo sueltan con lo que se pulsaron
    mutating func changePack(to pack: LoadedPack, settings: KeyboardSettings, sources: [String: LoadedPack]) {
        let pressed = self.pressed
        self = KeyboardSounds(pack: pack, settings: settings, sources: sources)
        self.pressed = pressed
    }

    /// Los mismos, con otros ajustes: lo que no ha cambiado se queda como estaba, sin remuestrear
    /// ni igualar otra vez
    func updated(settings: KeyboardSettings, sources: [String: LoadedPack]) -> KeyboardSounds {
        var result = self
        result.groups = [:]
        result.keys = [:]
        result.build(settings, sources: sources, reusing: self)
        return result
    }

    /// Lo que suena con una pulsación, si suena algo. El soltar y las repeticiones suenan con lo que
    /// sonó al pulsar, aunque entre medias hayas soltado las modificadoras: ⌘A suelta como ⌘A aunque
    /// sueltes antes el Cmd. Las repeticiones de una tecla mantenida suenan más flojo, y las del
    /// espacio no suenan: mantenerlo suele ser un modo, como mover el lienzo en Figma
    mutating func sound(for event: KeyEvent) -> Sound? {
        if event.isRepeat && event.keyCode == KeyGroup.spaceKey { return nil }
        var chord = KeyChord(keyCode: event.keyCode, flags: event.flags)
        if event.isDown && !event.isRepeat {
            pressed[event.keyCode] = chord
        } else if let held = pressed[event.keyCode] {
            chord = held
            if !event.isDown { pressed[event.keyCode] = nil }
        }
        let variants = sounds(for: chord, isDown: event.isDown)
        guard !variants.isEmpty else { return nil }
        return Sound(variants: variants, volume: event.isRepeat ? Self.repeatVolume : 1)
    }

    func sounds(for chord: KeyChord, isDown: Bool) -> [AVAudioPCMBuffer] {
        keys[chord]?.sounds(isDown: isDown) ?? below(chord, isDown: isDown)
    }

    /// La tecla sola
    func sounds(for keyCode: UInt16, isDown: Bool) -> [AVAudioPCMBuffer] {
        sounds(for: KeyChord(keyCode), isDown: isDown)
    }

    /// Todo lo que puede sonar: el pack, los grupos y las teclas cambiadas
    var allBuffers: [AVAudioPCMBuffer] {
        pack.allBuffers + groups.values.flatMap(\.sounds.allBuffers)
            + keys.values.flatMap { $0.sounds.down + $0.sounds.up }
    }

    //- Capas -

    /// Lo que suena en una tecla o un atajo sin contar si está cambiado: en un atajo, la tecla sola;
    /// en una tecla, su grupo o el pack activo
    private func below(_ chord: KeyChord, isDown: Bool) -> [AVAudioPCMBuffer] {
        if chord.isShortcut, let key = keys[chord.plain] { return key.sounds(isDown: isDown) }
        return (groups[KeyGroup(keyCode: chord.keyCode)]?.sounds ?? pack).sounds(for: chord.keyCode, isDown: isDown)
    }

    /// Lo cambiado que hay debajo de una tecla o un atajo, si hay algo
    private func base(of chord: KeyChord) -> Base? {
        if chord.isShortcut, let key = keys[chord.plain] { return .key(key.recipe) }
        return groups[KeyGroup(keyCode: chord.keyCode)].map { .group($0.recipe) }
    }

    private mutating func build(_ settings: KeyboardSettings, sources: [String: LoadedPack], reusing previous: KeyboardSounds?) {
        for (group, changed) in settings.changedGroups {
            if let layer = previous?.groups[group], layer.recipe == changed {
                groups[group] = layer
                continue
            }
            let target = loudness(of: group)
            if let sounds = sounds(of: group, changed, target: target, sources: sources) {
                groups[group] = Layer(recipe: changed, sounds: sounds)
            }
        }
        // Las teclas antes que los atajos, que pueden partir de ellas
        let changedKeys = settings.changedKeys.filter { !$0.key.isShortcut } + settings.changedKeys.filter(\.key.isShortcut)
        for changed in changedKeys {
            let recipe = KeyRecipe(changed: changed, base: changed.packID == nil ? base(of: changed.key) : nil)
            if let layer = previous?.keys[changed.key], layer.recipe == recipe {
                keys[changed.key] = layer
                continue
            }
            // Una tecla «Del pack» no la necesita: se queda a su propia altura
            let target = changed.packID == nil ? nil : loudness(of: KeyGroup(keyCode: changed.key.keyCode))
            if let sounds = sounds(of: changed, groupLoudness: target, sources: sources) {
                keys[changed.key] = Layer(recipe: recipe, sounds: sounds)
            }
        }
    }

    /// Cada tecla del grupo con la suya del pack de origen, a la altura del mismo grupo en el pack
    /// activo por su volumen: así no cambia lo que suenan unos grupos frente a otros. «Del pack»
    /// parte de los sonidos del pack activo, y a 1× no cambia nada
    private func sounds(
        of group: KeyGroup, _ changed: ChangedGroup, target: Float, sources: [String: LoadedPack]
    ) -> LoadedPack? {
        let source: LoadedPack
        if let id = changed.packID {
            guard let found = sources[id] else { return nil }
            source = found
        } else {
            source = pack
        }
        // El tono antes que la altura: más agudo es más corto, y suena algo más flojo
        return source.only(group).pitched(by: changed.pitch).leveled(to: target * Float(changed.volume))
    }

    private mutating func loudness(of group: KeyGroup) -> Float {
        if let known = groupLoudness[group] { return known }
        let measured = pack.only(group).typicalLoudness
        groupLoudness[group] = measured
        return measured
    }

    /// La tecla de origen, a la altura de su grupo en el pack activo (ver Loudness) por su volumen:
    /// una Return de otro pack suena como las anchas del pack activo. Una tecla «Del pack» parte de
    /// lo que ya suena en ella, con su propia altura: a 1× no cambia nada
    private func sounds(
        of changed: ChangedKey, groupLoudness: Float?, sources: [String: LoadedPack]
    ) -> Sounds? {
        let original: Sounds
        let target: Float
        if let id = changed.packID, let groupLoudness {
            guard let source = sources[id] else { return nil }
            original = Sounds(
                down: source.sounds(for: changed.sourceKey, isDown: true),
                up: source.sounds(for: changed.sourceKey, isDown: false)
            )
            target = groupLoudness
        } else {
            guard changed.isTuned else { return nil }
            original = Sounds(down: below(changed.key, isDown: true), up: below(changed.key, isDown: false))
            target = Loudness.typical(of: original.down)
        }
        // Un pack de una sola tecla: el tono y la altura, como en cualquier pack
        let key = changed.key.keyCode
        let tuned = LoadedPack(down: [key: original.down], up: [key: original.up])
            .pitched(by: changed.pitch)
            .leveled(to: target * Float(changed.volume))
        return Sounds(down: tuned.sounds(for: key, isDown: true), up: tuned.sounds(for: key, isDown: false))
    }
}
