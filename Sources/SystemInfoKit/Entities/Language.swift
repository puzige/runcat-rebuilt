import Foundation

enum Language {
    case automatic
    case chineseSimplified
    case chineseTraditional
    case english
    case french
    case german
    case japanese
    case korean
    case russian
    case spanish
    case vietnamese

    var locale: Locale {
        switch self {
        case .automatic:
            Locale.current
        case .chineseSimplified:
            Locale(languageCode: .chinese, script: .hanSimplified)
        case .chineseTraditional:
            Locale(languageCode: .chinese, script: .hanTraditional)
        case .english:
            Locale(languageCode: .english)
        case .french:
            Locale(languageCode: .french)
        case .german:
            Locale(languageCode: .german)
        case .japanese:
            Locale(languageCode: .japanese)
        case .korean:
            Locale(languageCode: .korean)
        case .russian:
            Locale(languageCode: .russian)
        case .spanish:
            Locale(languageCode: .spanish)
        case .vietnamese:
            Locale(languageCode: .vietnamese)
        }
    }

    var bundle: Bundle? {
        // SwiftPM's generated Bundle.module accessor only looks beside
        // Bundle.main.bundleURL.  That is correct for `swift run`, but a
        // hand-assembled macOS application stores resource bundles in
        // Contents/Resources.  Calling Bundle.module there traps before we
        // can recover.  Resolve the package bundle explicitly so the same
        // binary works both from SwiftPM and from RunCat.app.
        let resources = Self.resourceBundle
        if self != .automatic, let path = resources?.path(forResource: locale.identifier, ofType: "lproj") {
            return Bundle(path: path)
        } else {
            return resources
        }
    }

    private static let resourceBundle: Bundle? = {
        let bundleName = "RunCat_SystemInfoKit"
        let candidates = [
            Bundle.main.resourceURL?.appendingPathComponent("\(bundleName).bundle"),
            Bundle.main.bundleURL.appendingPathComponent("\(bundleName).bundle"),
            Bundle.main.bundleURL.deletingLastPathComponent().appendingPathComponent("\(bundleName).bundle"),
        ]
        return candidates.compactMap { $0 }.compactMap(Bundle.init(url:)).first
    }()
}
