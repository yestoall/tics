//· ChordCapture ·
// Elegir una tecla o un atajo pulsándolo, en los ajustes del teclado. Una modificadora no se elige
// al pulsarla, porque puede venir un atajo: si con ella pulsada llega otra tecla, se elige el atajo
// (⌘A), y si se sueltan todas sin más, la primera que pulsaste (⌘). Bloq Mayús se elige al
// encenderla o al apagarla.

struct ChordCapture {
    /// Las teclas que siguen abajo: al elegir, su soltar no debe sonar
    private(set) var held: Set<UInt16> = []
    /// La primera modificadora pulsada, que se elige si se sueltan todas sin más
    private var firstModifier: UInt16?

    /// Lo que se elige con este evento, si se elige algo
    mutating func handle(_ event: KeyEvent) -> KeyChord? {
        if event.isRepeat { return nil }
        if event.keyCode == KeyChord.capsLock { return KeyChord(event.keyCode) }
        guard event.isDown else {
            held.remove(event.keyCode)
            guard let first = firstModifier, held.isDisjoint(with: KeyChord.modifierKeys) else { return nil }
            firstModifier = nil
            return KeyChord(first)
        }
        held.insert(event.keyCode)
        if KeyChord.modifierKeys.contains(event.keyCode) {
            if firstModifier == nil { firstModifier = event.keyCode }
            return nil
        }
        firstModifier = nil
        return KeyChord(keyCode: event.keyCode, flags: event.flags)
    }
}
