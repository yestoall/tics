//· LogitechTests ·
// Los botones desviados de un ratón Logitech, a partir de lo que manda por Bluetooth. Los avisos
// son los que mandó de verdad un ratón, con Options+ abierto

import Foundation
import Testing
@testable import Tics

/// Un aviso de 18 bytes, como llegan: lo que se da y el resto a cero
private func report(_ bytes: [UInt8]) -> Data {
    Data(bytes + [UInt8](repeating: 0, count: 18 - bytes.count))
}

/// Las respuestas del ratón a nuestras preguntas: REPROG_CONTROLS_V4 está en el índice 0x0D,
/// DEVICE_NAME_TYPE en el 0x03, y el aparato es un ratón (3)
private let featureReply = report([0x00, 0x0A, 0x0D, 0x00, 0x05])
private let nameTypeReply = report([0x00, 0x0B, 0x03, 0x00, 0x01])
private let mouseReply = report([0x03, 0x2B, 0x03])

private let back: UInt16 = 0x0053

/// Un ratón que ya ha contestado a todo
private func mouse() -> DivertedButtons {
    var buttons = DivertedButtons()
    for reply in [featureReply, nameTypeReply, mouseReply] { _ = buttons.receive(reply) }
    return buttons
}

@Test func alPulsarUnBotonDesviadoSuenaSuPulsar() {
    var buttons = mouse()
    let changes = buttons.receive(report([0x0D, 0x00, 0x00, 0x53])).changes
    #expect(changes == [DivertedButtons.Change(control: back, isDown: true)])
}

@Test func unaPulsacionDeAtrasEsUnPulsarYUnSoltarAunqueOptionsAvisaDosVeces() {
    var buttons = mouse()
    // Como llegó del ratón: los botones abajo (orden 0) y, detrás, el aviso para las estadísticas
    // de Options+ (orden 2), que se ignora
    let sequence: [[UInt8]] = [
        [0x0D, 0x00, 0x00, 0x53],
        [0x0D, 0x20, 0x00, 0x53, 0x01],
        [0x0D, 0x00],
        [0x0D, 0x20, 0x00, 0x53, 0x00],
    ]
    let changes = sequence.flatMap { buttons.receive(report($0)).changes }
    #expect(changes == [
        DivertedButtons.Change(control: back, isDown: true),
        DivertedButtons.Change(control: back, isDown: false),
    ])
}

@Test func lasRespuestasAOtrosProgramasNoCambianDondeEstaLaFuncion() {
    var buttons = mouse()
    // Options+ pregunta por otra función, con su propio número de remitente (1): el ratón la tiene en 0x07
    _ = buttons.receive(report([0x00, 0x01, 0x07, 0x00, 0x01]))
    let changes = buttons.receive(report([0x0D, 0x00, 0x00, 0x53])).changes
    #expect(changes == [DivertedButtons.Change(control: back, isDown: true)])
}

@Test func sinSaberDondeEstaLaFuncionNoSuenaNada() {
    var buttons = DivertedButtons()
    #expect(buttons.receive(report([0x0D, 0x00, 0x00, 0x53])).changes.isEmpty)
}

@Test func alEmpezarPreguntaDondeEstanLasTresFunciones() {
    // getFeature (orden 0 de la función raíz, siempre en el 0), una por función y con un
    // remitente distinto, porque la respuesta no repite por cuál se preguntó
    #expect(DivertedButtons.requests == [
        report([0x00, 0x0A, 0x1B, 0x04]),
        report([0x00, 0x0B, 0x00, 0x05]),
        report([0x00, 0x0C, 0x19, 0xB0]),
    ])
}

@Test func alSaberDondeEstaDeviceNameTypePreguntaQueAparatoEs() {
    var buttons = DivertedButtons()
    // getDeviceType es la orden 2 de DEVICE_NAME_TYPE
    #expect(buttons.receive(nameTypeReply).nextRequest == report([0x03, 0x2B]))
}

@Test func unTecladoLogitechNoSuenaComoRaton() {
    var buttons = DivertedButtons()
    for reply in [featureReply, nameTypeReply, report([0x03, 0x2B, 0x00])] { _ = buttons.receive(reply) }
    #expect(buttons.receive(report([0x0D, 0x00, 0x00, 0x53])).changes.isEmpty)
}

@Test func hastaSaberQueEsUnRatonNoSuena() {
    var buttons = DivertedButtons()
    _ = buttons.receive(featureReply)
    #expect(buttons.receive(report([0x0D, 0x00, 0x00, 0x53])).changes.isEmpty)
}

//- Lo que inyecta Options+ -

@Test func elAgenteDeOptionsSeReconocePorSuRuta() {
    let agent = "/Library/Application Support/Logitech.localized/LogiOptionsPlus/logioptionsplus_agent.app/Contents/MacOS/logioptionsplus_agent"
    #expect(OptionsPlus.isAgent(path: agent))
    // Otros programas de Logitech, como Logi Tune, no ejecutan las funciones de los botones
    #expect(!OptionsPlus.isAgent(path: "/Applications/Logi Tune.app/Contents/MacOS/LogiTune"))
    #expect(!OptionsPlus.isAgent(path: "/Applications/logioptionsplus.app/Contents/MacOS/logioptionsplus"))
}

//- Listo para sonar -

@Test func soloEstaListoCuandoSabeDondeEstaLaFuncionYQueEsUnRaton() {
    var buttons = DivertedButtons()
    #expect(!buttons.isReady)
    _ = buttons.receive(featureReply)
    _ = buttons.receive(nameTypeReply)
    #expect(!buttons.isReady)
    _ = buttons.receive(mouseReply)
    #expect(buttons.isReady)
}

@Test func unTecladoNuncaEstaListo() {
    var buttons = DivertedButtons()
    for reply in [featureReply, nameTypeReply, report([0x03, 0x2B, 0x00])] { _ = buttons.receive(reply) }
    #expect(!buttons.isReady)
}

//- Vibración -

/// La respuesta del ratón: HAPTIC (0x19B0) está en el índice 0x0B, como en el MX Master 4
private let hapticReply = report([0x00, 0x0C, 0x0B, 0x00, 0x00])

@Test func conHapticLaVibracionEsLaOrdenCuatroConElIdDelEfecto() {
    var buttons = mouse()
    _ = buttons.receive(hapticReply)
    // Como la que hizo vibrar el ratón en la sonda: índice, orden 4 con el remitente, efecto
    #expect(buttons.vibration(.knock) == report([0x0B, 0x4C, 0x02]))
    #expect(buttons.vibration(.shake) == report([0x0B, 0x4C, 0x0B]))
    #expect(buttons.canVibrate)
}

@Test func sinHapticNoHayVibracion() {
    var buttons = mouse()
    #expect(buttons.vibration(.tap) == nil)
    // Un ratón que contesta que no la tiene
    _ = buttons.receive(report([0x00, 0x0C, 0x00]))
    #expect(buttons.vibration(.tap) == nil)
    #expect(!buttons.canVibrate)
}

@Test func ningunaVibracionNoMandaNada() {
    var buttons = mouse()
    _ = buttons.receive(hapticReply)
    #expect(buttons.vibration(.none) == nil)
}
