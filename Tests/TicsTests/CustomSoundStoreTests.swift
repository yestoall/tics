//· CustomSoundStoreTests ·
// Los sonidos propios: la copia que guarda TICS de un fichero tuyo, sin el silencio del principio y
// recortada, y el borrado de las que ya no usa ninguna tecla

import AVFoundation
import Foundation
import Testing
@testable import Tics

private let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 2)!

private func seconds(_ buffer: AVAudioPCMBuffer) -> Double {
    Double(buffer.frameLength) / buffer.format.sampleRate
}

@Test func laCopiaEmpiezaDondeSuenaYDuraComoMucho2Segundos() throws {
    let store = makeTestStore()
    let sound = try store.importSound(from: testWav(silence: 0.5, tone: 3))
    let copy = try #require(store.load(sound))
    #expect(copy.format == format)
    #expect(abs(seconds(copy) - CustomSoundStore.maxSeconds) < 0.01)
    // Lo primero que suena es el tono: en los primeros 5 ms ya hay sonido
    let firstMs = Int(format.sampleRate * 0.005)
    #expect((0..<firstMs).contains { abs(copy.floatChannelData![0][$0]) > 0.05 })
}

@Test func unFicheroQueNoEsAudioNoSeCopia() throws {
    let store = makeTestStore()
    let pdf = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).pdf")
    try Data("%PDF-1.4 no soy audio".utf8).write(to: pdf)
    #expect(throws: (any Error).self) { try store.importSound(from: pdf) }
    let copies = (try? FileManager.default.contentsOfDirectory(atPath: store.folder.path)) ?? []
    #expect(copies.isEmpty)
}

@Test func unaCopiaQueYaNoEstaNoSuena() throws {
    let store = makeTestStore()
    let sound = try store.importSound(from: testWav(silence: 0, tone: 0.5))
    try FileManager.default.removeItem(at: store.folder)
    #expect(store.load(sound) == nil)
}

@Test func seBorranLasCopiasQueNoUsaNingunaTecla() throws {
    let store = makeTestStore()
    let kept = try store.importSound(from: testWav(silence: 0, tone: 0.5, name: "uno.wav"))
    let unused = try store.importSound(from: testWav(silence: 0, tone: 0.5, name: "dos.wav"))
    store.removeAll(except: [kept])
    #expect(store.load(kept) != nil)
    #expect(store.load(unused) == nil)
    #expect(kept.name.hasSuffix("uno.wav"))
}

@Test func elSilencioDelPrincipioSeQuitaAunqueOcupeVariosTrozos() throws {
    let store = makeTestStore()
    let sound = try store.importSound(from: testWav(silence: 1.3, tone: 1))
    let copy = try #require(store.load(sound))
    // Solo el segundo de tono, sin el silencio
    #expect(abs(seconds(copy) - 1) < 0.01)
}

@Test func unFicheroQueEsTodoSilencioNoSeCopia() throws {
    let store = makeTestStore()
    #expect(throws: (any Error).self) { try store.importSound(from: testWav(silence: 1, tone: 0)) }
}
