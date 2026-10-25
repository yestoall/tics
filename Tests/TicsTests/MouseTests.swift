//· MouseTests ·
// El detector de arrastre, la medida de lo que suena un fragmento y los clics que se calculan

import AVFoundation
import CoreGraphics
import Testing
@testable import Tics

private let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 2)!
private let ms: UInt64 = 1_000_000

//- Arrastre -

@Test func moverPocoConElBotonPulsadoSigueSiendoUnClic() {
    var drag = DragTracker()
    drag.press(at: CGPoint(x: 100, y: 100), time: 0)
    let tick = drag.move(to: CGPoint(x: 103, y: 102), time: 10 * ms)
    #expect(tick == nil)
    #expect(!drag.isDragging)
    let wasDragging = drag.release()
    #expect(!wasDragging)
}

@Test func conElBotonPulsadoUnRatoUnAjusteFinoYaEsArrastre() {
    var drag = DragTracker()
    drag.press(at: CGPoint(x: 100, y: 100), time: 0)
    // 2 puntos: deprisa sería el temblor de un clic; tras 300 ms con el botón abajo, es arrastre
    let tick = drag.move(to: CGPoint(x: 102, y: 100), time: 300 * ms)
    #expect(tick != nil)
    #expect(drag.isDragging)
}

@Test func deprisaSuenaAlEmpezarYCadaCuarentaPuntos() {
    var drag = DragTracker()
    drag.press(at: .zero, time: 0)
    var ticks: [Bool] = []
    // Pasos de 10 puntos cada 10 ms (1000 puntos/s): el primero ya es arrastre, y luego uno de cada cuatro
    for step in 1...9 {
        ticks.append(drag.move(to: CGPoint(x: Double(step) * 10, y: 0), time: UInt64(step) * 10 * ms) != nil)
    }
    #expect(drag.isDragging)
    #expect(ticks == [true, false, false, false, true, false, false, false, true])
}

@Test func despacioLosClicsVanMasSeguidos() {
    var drag = DragTracker()
    drag.press(at: .zero, time: 0)
    var ticks: [Int] = []
    // Píxel a píxel: 1 punto cada 50 ms (20 puntos/s). A los 150 ms ya es arrastre, y luego
    // un clic cada 8 puntos. Con 40 fijos serían dos en 2 s
    for step in 1...40 {
        if drag.move(to: CGPoint(x: Double(step), y: 0), time: UInt64(step) * 50 * ms) != nil { ticks.append(step) }
    }
    #expect(ticks == [3, 11, 19, 27, 35])
}

@Test func despacioSuenaMasFlojoQueDeprisa() throws {
    var slow = DragTracker()
    slow.press(at: .zero, time: 0)
    var slowVolume: Float?
    for step in 1...3 { slowVolume = slow.move(to: CGPoint(x: Double(step), y: 0), time: UInt64(step) * 50 * ms) ?? slowVolume }

    var fast = DragTracker()
    fast.press(at: .zero, time: 0)
    let fastVolume = fast.move(to: CGPoint(x: 10, y: 0), time: 10 * ms)

    #expect(try #require(slowVolume) == DragTracker.slowVolume)
    #expect(try #require(fastVolume) == 1)
}

@Test func unArrastreQueLlegaSinSuClicSuenaDesdeElPrimerMovimiento() {
    var drag = DragTracker()
    // Otra app (yabai, al mover ventanas con Alt) se quedó el pulsar: llegan solo los movimientos
    let first = drag.join(at: .zero, time: 0)
    #expect(first > 0)
    #expect(drag.isDragging)
    var ticks: [Bool] = []
    // Y luego, como cualquier arrastre: deprisa, uno cada 40 puntos
    for step in 1...4 {
        ticks.append(drag.move(to: CGPoint(x: Double(step) * 10, y: 0), time: UInt64(step) * 10 * ms) != nil)
    }
    #expect(ticks == [false, false, false, true])
}

@Test func deprisaLosClicsNoSeAmontonan() {
    var drag = DragTracker()
    drag.press(at: .zero, time: 0)
    var count = 0
    // 100 puntos cada 5 ms: sin tope serían 20 clics en 100 ms; con él, como mucho uno cada 35 ms
    for step in 1...20 {
        if drag.move(to: CGPoint(x: Double(step) * 100, y: 0), time: UInt64(step) * 5 * ms) != nil { count += 1 }
    }
    #expect(count == 3)
}

@Test func soltarDiceSiHabiaArrastreYEmpiezaDeCero() {
    var drag = DragTracker()
    drag.press(at: .zero, time: 0)
    _ = drag.move(to: CGPoint(x: 50, y: 0), time: 10 * ms)
    let wasDragging = drag.release()
    #expect(wasDragging)
    #expect(!drag.isDragging)
    let tick = drag.move(to: CGPoint(x: 200, y: 0), time: 20 * ms)
    #expect(tick == nil)
}

@Test func sinPulsarNoHayArrastre() {
    var drag = DragTracker()
    let tick = drag.move(to: CGPoint(x: 500, y: 500), time: 10 * ms)
    #expect(tick == nil)
}

//- Rueda -

@Test func unaMuescaDeLaRuedaSuena() {
    var scroll = ScrollTracker()
    let tick = scroll.scroll(lines: 1, phase: 0, momentum: 0, time: 0)
    #expect(tick)
}

@Test func losEventosDeLaRuedaSinLineasNoSuenan() {
    var scroll = ScrollTracker()
    // El desplazamiento suave manda trocitos de pocos puntos sin llegar a una línea
    let tick = scroll.scroll(lines: 0, phase: 0, momentum: 0, time: 0)
    #expect(!tick)
}

@Test func laRuedaLanzadaNoSeVuelveUnaRafaga() {
    var scroll = ScrollTracker()
    var count = 0
    // 3 líneas cada 10 ms durante 200 ms: como mucho un clic cada 35 ms (a los 0, 40, 80, 120 y 160)
    for step in 0..<20 {
        if scroll.scroll(lines: 3, phase: 0, momentum: 0, time: UInt64(step) * 10 * ms) { count += 1 }
    }
    #expect(count == 5)
}

@Test func elTrackpadNoSuena() {
    var scroll = ScrollTracker()
    // El trackpad manda sus eventos con fase (empieza, sigue, acaba) o con inercia: no tiene muescas
    let swiping = scroll.scroll(lines: 2, phase: 2, momentum: 0, time: 0)
    let coasting = scroll.scroll(lines: 2, phase: 0, momentum: 2, time: 100 * ms)
    #expect(!swiping)
    #expect(!coasting)
}

//- Lo que suena -

private func constant(_ value: Float, ms: Double) -> AVAudioPCMBuffer {
    let frames = AVAudioFrameCount(ms * format.sampleRate / 1000)
    let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames)!
    for channel in 0..<2 {
        for i in 0..<Int(frames) { buffer.floatChannelData![channel][i] = value }
    }
    buffer.frameLength = frames
    return buffer
}

@Test func unSonidoLargoMideLoQueSuValor() {
    #expect(abs(Loudness.of(constant(0.5, ms: 300)) - 0.5) < 0.001)
}

@Test func unSonidoCortoCuentaComoMasFlojo() {
    // La mitad de la ventana: la mitad de energía, √½ de valor
    #expect(abs(Loudness.of(constant(0.5, ms: 50)) - Float(0.5).squareRoot() / 2) < 0.01)
}

@Test func cadaBotonTieneSusClicsALaAlturaDelPack() {
    let keyLoudness: Float = 0.02
    let clicks = MouseSynth.clicks(format: format, keyLoudness: keyLoudness)
    let expected = keyLoudness * MouseSynth.loudness
    for button in MouseButton.allCases {
        for buffers in [clicks.down[button], clicks.up[button]] {
            #expect(buffers?.count == MouseSynth.variantCount)
            for buffer in buffers ?? [] {
                #expect(buffer.format == format)
                #expect(abs(Loudness.of(buffer) - expected) < expected * 0.01)
            }
        }
    }
    #expect(clicks.drag.count == MouseSynth.variantCount)
    for buffer in clicks.drag {
        let dragExpected = keyLoudness * MouseSynth.dragLoudness
        #expect(abs(Loudness.of(buffer) - dragExpected) < dragExpected * 0.01)
    }
}

@Test func conUnPackMuyFuerteLosClicsNoSaturan() {
    let clicks = MouseSynth.clicks(format: format, keyLoudness: 1)
    for buffer in clicks.down.values.flatMap({ $0 }) + clicks.drag {
        let samples = UnsafeBufferPointer(start: buffer.floatChannelData![0], count: Int(buffer.frameLength))
        #expect((samples.map(abs).max() ?? 0) <= Synth.maxPeak + 0.0001)
    }
}
