//· Language ·
// El idioma de TICS: el del Mac, salvo que se elija otro en el panel. Se guarda donde lo guarda
// Ajustes del Sistema cuando eliges el idioma de una app (AppleLanguages, en las preferencias de
// TICS), y macOS lo aplica al arrancar: por eso cambiarlo reinicia la app.

import Foundation

enum Language: String, CaseIterable {
    case es, en

    /// Cada idioma, con su nombre en ese idioma: «Español», «English»
    var name: String {
        let locale = Locale(identifier: rawValue)
        return locale.localizedString(forLanguageCode: rawValue)?.capitalized(with: locale) ?? rawValue
    }

    /// El idioma en el que sale TICS ahora
    static var current: Language {
        Bundle.main.preferredLocalizations.first.flatMap(Language.init) ?? .en
    }

    /// Los idiomas del Mac, sin lo que se haya elegido para TICS
    static var system: [String] {
        CFPreferencesCopyValue("AppleLanguages" as CFString, kCFPreferencesAnyApplication,
                               kCFPreferencesCurrentUser, kCFPreferencesAnyHost) as? [String] ?? []
    }

    /// El idioma que elige macOS para TICS con esas preferencias. El inglés va primero en la lista:
    /// un Mac en un idioma que TICS no tiene la ve en inglés
    static func resolve(_ preferences: [String]) -> Language {
        Bundle.preferredLocalizations(from: [Language.en, .es].map(\.rawValue), forPreferences: preferences)
            .first.flatMap(Language.init) ?? .en
    }

    /// Lo que hay que guardar en AppleLanguages para que TICS salga en este idioma: nada si ya es
    /// el que tocaría con los idiomas del Mac, y así sigue al Mac si este cambia
    func override(system: [String]) -> [String]? {
        Language.resolve(system) == self ? nil : [rawValue]
    }
}
