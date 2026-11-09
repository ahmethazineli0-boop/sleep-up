// Shield Configuration uzantısı: kilitli uygulama açılınca görünen ekran.
// Apple bu ekranda yalnızca ikon, başlık, alt yazı ve iki düğmeye izin verir.

import ManagedSettings
import ManagedSettingsUI
import UIKit

class ShieldConfigurationExtension: ShieldConfigurationDataSource {

    override func configuration(shielding application: Application) -> ShieldConfiguration {
        make()
    }

    override func configuration(shielding application: Application, in category: ActivityCategory) -> ShieldConfiguration {
        make()
    }

    override func configuration(shielding webDomain: WebDomain) -> ShieldConfiguration {
        make()
    }

    override func configuration(shielding webDomain: WebDomain, in category: ActivityCategory) -> ShieldConfiguration {
        make()
    }

    private func make() -> ShieldConfiguration {
        let store = SharedStore.shared
        var subtitle = "Uyku saatin başladı. Ekranı bırak, yarın burada olacak."
        if let until = store.lockUntil() {
            let f = DateFormatter()
            f.locale = Locale(identifier: "tr_TR")
            f.dateFormat = "HH:mm"
            subtitle = "Bu uygulama \(f.string(from: until))'e kadar kilitli. Acil açma için Sleep Up'ı aç."
        }
        return ShieldConfiguration(
            backgroundBlurStyle: .systemUltraThinMaterialDark,
            backgroundColor: UIColor(red: 0.03, green: 0.03, blue: 0.06, alpha: 1),
            icon: UIImage(systemName: "moon.zzz.fill")?
                .withTintColor(UIColor(red: 0.96, green: 0.72, blue: 0.38, alpha: 1), renderingMode: .alwaysOriginal),
            title: .init(text: "Telefonun uyuyor", color: .white),
            subtitle: .init(text: subtitle, color: UIColor(white: 0.75, alpha: 1)),
            primaryButtonLabel: .init(text: "Tamam, uyuyorum", color: UIColor(red: 0.1, green: 0.08, blue: 0.02, alpha: 1)),
            primaryButtonBackgroundColor: UIColor(red: 0.96, green: 0.72, blue: 0.38, alpha: 1),
            secondaryButtonLabel: nil
        )
    }
}
