//· LogitechMonitor ·
// Escucha los botones desviados de los ratones Logitech conectados por Bluetooth. Se suscribe,
// como un segundo oyente, al servicio Bluetooth propio de Logitech, por el que el ratón avisa a
// Options+ de cada pulsar y soltar; lo que manda lo descifra `DivertedButtons`.
// No desconecta ni cambia nada del ratón: solo le pregunta qué es y dónde tiene sus funciones, y
// lo hace vibrar si en los ajustes del ratón se ha elegido una vibración (HAPTIC, orden 4).
// Pide el permiso de Bluetooth: macOS lo pregunta la primera vez que se crea el CBCentralManager.

@preconcurrency import CoreBluetooth
import IOKit.hid
import os

@MainActor
final class LogitechMonitor: NSObject {
    enum Permission {
        case notAsked
        case granted
        case denied
    }

    /// El servicio propio de Logitech y la característica por la que van los mensajes HID++
    private static let service = CBUUID(string: "00010000-0000-1000-8000-011F2000046D")
    private static let characteristic = CBUUID(string: "00010001-0000-1000-8000-011F2000046D")
    private static let vendorID = 0x046D
    /// El MX Master 4 por Bluetooth: según Logitech, el único que vibra
    private static let hapticProductIDs: Set<Int> = [0xB042]

    /// Se llama en el hilo principal con cada botón desviado que baja o sube
    var onButton: (@MainActor (_ isDown: Bool) -> Void)?

    /// Un aparato con el servicio de Logitech al que estamos suscritos, con lo que se sabe de él
    private struct Mouse {
        let peripheral: CBPeripheral
        var buttons = DivertedButtons()
        /// Por donde se le escribe: hasta que se descubre, nil
        var characteristic: CBCharacteristic?
    }

    private var central: CBCentralManager?
    private var mice: [UUID: Mouse] = [:]
    /// La muestra de una vibración pedida antes de que el ratón contestara: se lanza al contestar
    private var pendingVibration: Vibration?
    private let log = Logger(subsystem: "com.yestoall.tics", category: "LogitechMonitor")

    var isRunning: Bool { central != nil }

    /// Si hay al menos un ratón que ya ha contestado y cuyos botones desviados suenan
    var isListening: Bool { mice.values.contains { $0.buttons.isReady } }

    /// Hace vibrar los ratones que vibran. Si aún no ha contestado ninguno, la guarda para entonces
    func vibrate(_ vibration: Vibration) {
        var sent = false
        for mouse in mice.values {
            guard let message = mouse.buttons.vibration(vibration), let characteristic = mouse.characteristic else { continue }
            mouse.peripheral.writeValue(message, for: characteristic, type: .withResponse)
            sent = true
        }
        pendingVibration = sent ? nil : vibration
    }

    /// Leerlo no pregunta nada
    static var permission: Permission {
        switch CBManager.authorization {
        case .allowedAlways: .granted
        case .notDetermined: .notAsked
        default: .denied
        }
    }

    /// Si hay un ratón Logitech conectado por Bluetooth, y si alguno vibra. Se mira en IOKit, que no
    /// pide el permiso de Bluetooth: así la ficha y la vibración solo salen a quien le sirven
    static func connectedMice() -> (any: Bool, vibrating: Bool) {
        let mice = bluetoothMice()
        let vibrating = mice.contains { device in
            (IOHIDDeviceGetProperty(device, kIOHIDProductIDKey as CFString) as? Int).map(hapticProductIDs.contains) == true
        }
        return (!mice.isEmpty, vibrating)
    }

    private static func bluetoothMice() -> [IOHIDDevice] {
        let manager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))
        IOHIDManagerSetDeviceMatching(manager, [
            kIOHIDVendorIDKey: vendorID,
            kIOHIDPrimaryUsagePageKey: kHIDPage_GenericDesktop,
            kIOHIDPrimaryUsageKey: kHIDUsage_GD_Mouse,
        ] as CFDictionary)
        guard let devices = IOHIDManagerCopyDevices(manager) as? Set<IOHIDDevice> else { return [] }
        return devices.filter { device in
            let transport = IOHIDDeviceGetProperty(device, kIOHIDTransportKey as CFString) as? String
            return transport?.hasPrefix("Bluetooth") == true
        }
    }

    /// La primera vez, macOS pregunta por el permiso de Bluetooth
    func start() {
        guard central == nil else { return }
        central = CBCentralManager(delegate: self, queue: nil)
        log.info("Escucha de los botones desviados en marcha")
    }

    func stop() {
        guard let central else { return }
        // Solo cierra nuestra conexión: el ratón sigue conectado al Mac y a Options+
        for mouse in mice.values { central.cancelPeripheralConnection(mouse.peripheral) }
        mice = [:]
        self.central = nil
        log.info("Escucha de los botones desviados parada")
    }

    /// Los que ya están conectados al Mac con el servicio de Logitech. Se mira de nuevo cada vez
    /// que AppState repasa las escuchas, por si se ha conectado otro
    func connectNewMice() {
        guard let central, central.state == .poweredOn else { return }
        for peripheral in central.retrieveConnectedPeripherals(withServices: [Self.service])
        where mice[peripheral.identifier] == nil {
            mice[peripheral.identifier] = Mouse(peripheral: peripheral)
            peripheral.delegate = self
            log.info("Conectando con \(peripheral.name ?? "?", privacy: .public)")
            central.connect(peripheral)
        }
    }

    //- Lo que manda el ratón -

    fileprivate func didConnect(_ peripheral: CBPeripheral) {
        log.info("Conectado con \(peripheral.name ?? "?", privacy: .public)")
        peripheral.discoverServices([Self.service])
    }

    fileprivate func didDisconnect(_ peripheral: CBPeripheral) {
        log.info("Desconectado de \(peripheral.name ?? "?", privacy: .public)")
        mice[peripheral.identifier] = nil
    }

    fileprivate func didDiscover(_ characteristic: CBCharacteristic, of peripheral: CBPeripheral) {
        mice[peripheral.identifier]?.characteristic = characteristic
        peripheral.setNotifyValue(true, for: characteristic)
        for request in DivertedButtons.requests {
            peripheral.writeValue(request, for: characteristic, type: .withResponse)
        }
    }

    fileprivate func didReceive(_ value: Data, from peripheral: CBPeripheral, on characteristic: CBCharacteristic) {
        guard var mouse = mice[peripheral.identifier] else { return }
        let wasReady = mouse.buttons.isReady
        let couldVibrate = mouse.buttons.canVibrate
        let reply = mouse.buttons.receive(value)
        mice[peripheral.identifier] = mouse
        if !wasReady && mouse.buttons.isReady {
            log.info("\(peripheral.name ?? "?", privacy: .public): suenan sus botones desviados")
        }
        if !couldVibrate && mouse.buttons.canVibrate {
            log.info("\(peripheral.name ?? "?", privacy: .public): vibra")
            if let pendingVibration { vibrate(pendingVibration) }
        }
        if let request = reply.nextRequest { peripheral.writeValue(request, for: characteristic, type: .withResponse) }
        for change in reply.changes {
            log.debug("Botón desviado 0x\(String(format: "%04X", change.control), privacy: .public) \(change.isDown ? "abajo" : "arriba", privacy: .public)")
            onButton?(change.isDown)
        }
    }
}

//- Delegados de CoreBluetooth -
// Con `queue: nil`, CoreBluetooth llama en la cola principal: se entra al MainActor sin saltos

extension LogitechMonitor: CBCentralManagerDelegate, CBPeripheralDelegate {
    nonisolated func centralManagerDidUpdateState(_ central: CBCentralManager) {
        MainActor.assumeIsolated {
            if central.state == .poweredOn { connectNewMice() }
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        MainActor.assumeIsolated { didConnect(peripheral) }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        MainActor.assumeIsolated { didDisconnect(peripheral) }
    }

    nonisolated func centralManager(
        _ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?
    ) {
        MainActor.assumeIsolated { didDisconnect(peripheral) }
    }

    nonisolated func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        MainActor.assumeIsolated {
            for service in peripheral.services ?? [] where service.uuid == Self.service {
                peripheral.discoverCharacteristics([Self.characteristic], for: service)
            }
        }
    }

    nonisolated func peripheral(
        _ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?
    ) {
        MainActor.assumeIsolated {
            for characteristic in service.characteristics ?? [] where characteristic.uuid == Self.characteristic {
                didDiscover(characteristic, of: peripheral)
            }
        }
    }

    nonisolated func peripheral(
        _ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?
    ) {
        MainActor.assumeIsolated {
            if let value = characteristic.value { didReceive(value, from: peripheral, on: characteristic) }
        }
    }
}
