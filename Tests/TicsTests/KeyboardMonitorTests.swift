//· KeyboardMonitorTests ·
// De lo que trae el tap del teclado a la tecla que suena: la tecla del globo, Bloq Mayús y las
// modificadoras, que no mandan pulsar y soltar sino un cambio de flags

import CoreGraphics
import Testing
@testable import Tics

private let keyA: UInt16 = 0x00
private let leftShift: UInt16 = 0x38
private let rightShift: UInt16 = 0x3C
private let leftShiftBit: UInt64 = 0x0000_0002
private let rightShiftBit: UInt64 = 0x0000_0004
private let shift = CGEventFlags.maskShift.rawValue

private func raw(_ type: CGEventType, _ keyCode: UInt16, flags: UInt64 = 0, autorepeat: Bool = false) -> RawKeyEvent {
    RawKeyEvent(type: type, keyCode: keyCode, isAutorepeat: autorepeat, flags: flags, timestamp: 0, sourcePID: 0)
}

@Test func unaTeclaPulsaSueltaYRepite() throws {
    let pressed = try #require(raw(.keyDown, keyA).keyEvent)
    #expect(pressed.keyCode == keyA && pressed.isDown && !pressed.isRepeat)
    #expect(raw(.keyUp, keyA).keyEvent?.isDown == false)
    #expect(raw(.keyDown, keyA, autorepeat: true).keyEvent?.isRepeat == true)
}

@Test func laTeclaDelGloboNoSuenaDosVeces() {
    #expect(raw(.keyDown, 0xB3).keyEvent == nil)
}

@Test func bloqMayusPulsaAlEncenderseYSueltaAlApagarse() {
    #expect(raw(.flagsChanged, KeyChord.capsLock, flags: CGEventFlags.maskAlphaShift.rawValue).keyEvent?.isDown == true)
    #expect(raw(.flagsChanged, KeyChord.capsLock).keyEvent?.isDown == false)
}

@Test func unaModificadoraSeMiraPorSuPropioBit() {
    #expect(raw(.flagsChanged, leftShift, flags: shift | leftShiftBit).keyEvent?.isDown == true)
    // Con el Mayúsculas derecho aún abajo, el izquierdo se ha soltado
    #expect(raw(.flagsChanged, leftShift, flags: shift | rightShiftBit).keyEvent?.isDown == false)
    #expect(raw(.flagsChanged, rightShift, flags: shift | rightShiftBit).keyEvent?.isDown == true)
}

@Test func unCambioDeFlagsDeOtraTeclaNoSuena() {
    #expect(raw(.flagsChanged, keyA, flags: shift).keyEvent == nil)
    #expect(raw(.mouseMoved, keyA).keyEvent == nil)
}
