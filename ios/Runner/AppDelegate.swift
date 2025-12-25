#if canImport(Flutter)
    import Flutter
    import UIKit
    import YandexMapsMobile
    import flutter_local_notifications

    @main
    @objc class AppDelegate: FlutterAppDelegate {

        override func application(
            _ application: UIApplication,
            didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
        ) -> Bool {

            // 1️⃣ local notifications isolate registratsiya qilish
            FlutterLocalNotificationsPlugin.setPluginRegistrantCallback { registry in
                GeneratedPluginRegistrant.register(with: registry)
            }

            // 2️⃣ Foreground notifications banner/sound chiqishi uchun delegate
            if #available(iOS 10.0, *) {
                UNUserNotificationCenter.current().delegate = self
            }

            // 3️⃣ Yandex MapKit initialize
            configureYandexMapKit()

            // 4️⃣ Flutter pluginlarni ro‘yxatdan o‘tkazish
            GeneratedPluginRegistrant.register(with: self)

            return super.application(
                application,
                didFinishLaunchingWithOptions: launchOptions
            )
        }

        // 🔥 iOS foreground banner & sound ko‘rsatish
        @available(iOS 10.0, *)
        override func userNotificationCenter(
            _ center: UNUserNotificationCenter,
            willPresent notification: UNNotification,
            withCompletionHandler completionHandler:
                @escaping (UNNotificationPresentationOptions) -> Void
        ) {
            completionHandler([.banner, .list, .sound, .badge])
        }

        // 🔧 iOS 12+: notification settings ochilganda Flutter’ga qaytarish
        @available(iOS 12.0, *)
        override func userNotificationCenter(
            _ center: UNUserNotificationCenter,
            openSettingsFor notification: UNNotification?
        ) {
            if let controller = window?.rootViewController as? FlutterViewController {
                let channel = FlutterMethodChannel(
                    name: "com.example.flutter_local_notifications_example/settings",
                    binaryMessenger: controller.binaryMessenger
                )
                channel.invokeMethod("showNotificationSettings", arguments: nil)
            }
        }

        // MARK: - Yandex Map config

        private func configureYandexMapKit() {
            let apiKey = "2e1fd6f5-894a-4ecf-8fd4-70572e2bfb40"

            if !apiKey.isEmpty {
                YMKMapKit.setLocale("ru_RU")
                YMKMapKit.setApiKey(apiKey)
            }

        }

        private func envValue(for key: String) -> String? {
            guard let path = envFilePath(),
                let contents = try? String(contentsOfFile: path, encoding: .utf8)
            else { return nil }

            for rawLine in contents.split(whereSeparator: \.isNewline) {
                let line = rawLine.trimmingCharacters(in: .whitespaces)
                if line.isEmpty || line.hasPrefix("#") { continue }

                let parts = line.split(separator: "=", maxSplits: 1).map {
                    $0.trimmingCharacters(in: .whitespacesAndNewlines)
                }
                if parts.count == 2 && parts[0] == key {
                    return parts[1].trimmingCharacters(in: CharacterSet(charactersIn: "\"'"))
                }
            }
            return nil
        }

        private func envFilePath() -> String? {
            let assetKey = FlutterDartProject.lookupKey(forAsset: ".env")
            return Bundle.main.path(forResource: assetKey, ofType: nil)
        }
    }
#endif
