//· KeyboardSettings ·
// Los ajustes del teclado: los grupos de teclas, cada uno con las teclas de otro pack, y las teclas
// cambiadas, cada una con el sonido de una tecla de otro pack. Son una capa encima del pack que
// tengas puesto, así que valen con todos. Solo hay un juego, que se guarda en las preferencias
// cada vez que cambia (el tono y el volumen, al soltar su slider). Tienen los mismos topes que los
// del ratón (SoundSettings).

/// Un grupo de teclas que suena con las teclas de otro pack: cada una con la suya, a la altura del
/// mismo grupo en el pack activo
struct ChangedGroup: Codable, Equatable, Sendable {
    /// El id del pack del que salen. Sin él («Del pack»), el grupo suena con el pack activo
    var packID: String?
    /// Como en una tecla cambiada
    var pitch = 1.0
    var volume = 1.0

    /// Si suena igual que en el pack activo
    var isDefault: Bool { packID == nil && pitch == 1 && volume == 1 }

    var clamped: ChangedGroup {
        var result = self
        result.pitch = SoundSettings.clampedPitch(pitch)
        result.volume = SoundSettings.clampedVolume(volume)
        return result
    }
}

extension ChangedGroup {
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        packID = try container.decodeIfPresent(String.self, forKey: .packID)
        pitch = try container.decodeIfPresent(Double.self, forKey: .pitch) ?? 1
        volume = try container.decodeIfPresent(Double.self, forKey: .volume) ?? 1
        self = clamped
    }
}

/// Una tecla o un atajo que suena con el sonido de una tecla de otro pack, a la altura de su grupo
/// en el pack activo
struct ChangedKey: Codable, Equatable, Identifiable, Sendable {
    /// La tecla o el atajo que cambia. En un atajo, las modificadoras siguen sonando como siempre:
    /// lo que cambia es la tecla
    var key: KeyChord
    /// El id del pack del que sale el sonido. Sin él («Del pack», recién elegida la tecla), suena
    /// como en el pack activo, cambies al que cambies
    var packID: String?
    /// La tecla de ese pack que suena
    var sourceKey: UInt16
    /// Multiplica la velocidad de la grabación: más agudo es más corto. Pulsar y soltar van juntos
    var pitch = 1.0
    /// Multiplica la altura a la que suena, la del pack activo
    var volume = 1.0

    var id: KeyChord { key }

    /// Si suena distinto de su grabación
    var isTuned: Bool { pitch != 1 || volume != 1 }

    /// Dentro de sus rangos: lo guardado en otra versión puede venir de fuera
    var clamped: ChangedKey {
        var result = self
        result.pitch = SoundSettings.clampedPitch(pitch)
        result.volume = SoundSettings.clampedVolume(volume)
        return result
    }
}

extension ChangedKey {
    /// Lo guardado antes del tono y el volumen no los trae: se leen a 1×. En una extensión, para no
    /// perder el init de todos los campos
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        key = try container.decode(KeyChord.self, forKey: .key)
        packID = try container.decodeIfPresent(String.self, forKey: .packID)
        sourceKey = try container.decode(UInt16.self, forKey: .sourceKey)
        pitch = try container.decodeIfPresent(Double.self, forKey: .pitch) ?? 1
        volume = try container.decodeIfPresent(Double.self, forKey: .volume) ?? 1
        self = clamped
    }
}

struct KeyboardSettings: Codable, Equatable, Sendable {
    /// Solo los que no suenan como en el pack activo
    private(set) var changedGroups: [KeyGroup: ChangedGroup] = [:]
    /// En el orden en que se cambiaron; una tecla sale una sola vez
    private(set) var changedKeys: [ChangedKey] = []
    /// Cada pulsación un poco más grave o más aguda, al azar (PitchVariants). Encendido de serie
    var variesPitch = true

    /// Cómo suena un grupo de teclas
    subscript(group: KeyGroup) -> ChangedGroup {
        get { changedGroups[group] ?? ChangedGroup() }
        set {
            let changed = newValue.clamped
            changedGroups[group] = changed.isDefault ? nil : changed
        }
    }

    /// Lo que suena en una tecla o un atajo, si está cambiado
    subscript(key: KeyChord) -> ChangedKey? {
        changedKeys.first { $0.key == key }
    }

    /// Cambia una tecla, o la vuelve a cambiar si ya lo estaba
    mutating func change(_ changed: ChangedKey) {
        let changed = changed.clamped
        if let index = changedKeys.firstIndex(where: { $0.key == changed.key }) {
            changedKeys[index] = changed
        } else {
            changedKeys.append(changed)
        }
    }

    /// La tecla vuelve a sonar con el pack activo
    mutating func remove(_ key: KeyChord) {
        changedKeys.removeAll { $0.key == key }
    }

    /// Lo que se usa de cada pack de origen: lo demás no hace falta tenerlo en memoria
    var sources: [String: SourceUse] {
        var result: [String: SourceUse] = [:]
        for (group, changed) in changedGroups {
            if let id = changed.packID { result[id, default: SourceUse()].groups.insert(group) }
        }
        for changed in changedKeys {
            if let id = changed.packID { result[id, default: SourceUse()].keys.insert(changed.sourceKey) }
        }
        return result
    }
}

extension KeyboardSettings {
    /// Lo guardado antes de los grupos no los trae, ni lo de antes de variar el tono, que se lee
    /// encendido, como sale de serie
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        changedGroups = try container.decodeIfPresent([KeyGroup: ChangedGroup].self, forKey: .changedGroups) ?? [:]
        changedKeys = try container.decodeIfPresent([ChangedKey].self, forKey: .changedKeys) ?? []
        variesPitch = try container.decodeIfPresent(Bool.self, forKey: .variesPitch) ?? true
        changedGroups = changedGroups.filter { !$0.value.isDefault }
    }
}

/// Los grupos de teclas y las teclas de un pack de los que sale algún sonido
struct SourceUse: Equatable, Sendable {
    var groups: Set<KeyGroup> = []
    var keys: Set<UInt16> = []

    func contains(_ other: SourceUse) -> Bool {
        other.groups.isSubset(of: groups) && other.keys.isSubset(of: keys)
    }
}
