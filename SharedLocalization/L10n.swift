import Foundation

public enum L10n {
    public static func string(
        _ key: String.LocalizationValue,
        locale: Locale? = nil,
        bundle: Bundle = .main
    ) -> String {
        let resolved = locale ?? AppLanguageStore.shared.resolvedLocale
        let resource = LocalizedStringResource(key, locale: resolved, bundle: .atURL(bundle.bundleURL))
        return String(localized: resource)
    }

    public static func format(
        _ key: String.LocalizationValue,
        locale: Locale? = nil,
        bundle: Bundle = .main,
        _ arguments: CVarArg...
    ) -> String {
        let resolved = locale ?? AppLanguageStore.shared.resolvedLocale
        let template = string(key, locale: resolved, bundle: bundle)
        return String(format: template, locale: resolved, arguments: arguments)
    }
}
