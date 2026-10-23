#if canImport(Flutter)
    import Flutter
    import UIKit
    import YandexMapsMobile
    import flutter_local_notifications

    @main
    @objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {

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

            return super.application(
                application,
                didFinishLaunchingWithOptions: launchOptions
            )
        }

        func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
            GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
            guard let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "SardobaAppUpdate") else {
                return
            }
            let channel = FlutterMethodChannel(
                name: "com.sardoba/app_update",
                binaryMessenger: registrar.messenger()
            )
            channel.setMethodCallHandler { [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
                switch call.method {
                case "getAppInfo":
                    guard let rawVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String else {
                        result(FlutterError(
                            code: "APP_VERSION_UNAVAILABLE",
                            message: "Installed app version is unavailable",
                            details: nil
                        ))
                        return
                    }
                    let version = rawVersion.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !version.isEmpty else {
                        result(FlutterError(
                            code: "APP_VERSION_UNAVAILABLE",
                            message: "Installed app version is unavailable",
                            details: nil
                        ))
                        return
                    }
                    result(["version": version, "platform": "ios"])
                case "checkForUpdate":
                    self?.checkAppStoreVersion(result: result)
                default:
                    result(FlutterMethodNotImplemented)
                }
            }
        }

        private func checkAppStoreVersion(result: @escaping FlutterResult) {
            var components = URLComponents(string: "https://itunes.apple.com/lookup")!
            components.queryItems = [
                URLQueryItem(name: "id", value: "6757268380"),
                URLQueryItem(name: "country", value: "uz")
            ]
            guard let url = components.url else {
                result(["updateAvailable": false])
                return
            }

            var request = URLRequest(url: url)
            request.timeoutInterval = 5
            URLSession.shared.dataTask(with: request) { data, response, error in
                guard error == nil,
                      let http = response as? HTTPURLResponse,
                      (200..<300).contains(http.statusCode),
                      let data,
                      let payload = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let results = payload["results"] as? [[String: Any]],
                      let app = results.first,
                      let latestVersion = app["version"] as? String,
                      let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
                else {
                    DispatchQueue.main.async { result(["updateAvailable": false]) }
                    return
                }

                let updateAvailable = Self.compareVersions(latestVersion, currentVersion) > 0
                DispatchQueue.main.async {
                    result(["updateAvailable": updateAvailable, "latestVersion": latestVersion])
                }
            }.resume()
        }

        private static func compareVersions(_ lhs: String, _ rhs: String) -> Int {
            let left = lhs.split(separator: ".").map { Int($0) ?? 0 }
            let right = rhs.split(separator: ".").map { Int($0) ?? 0 }
            for index in 0..<max(left.count, right.count) {
                let leftPart = index < left.count ? left[index] : 0
                let rightPart = index < right.count ? right[index] : 0
                if leftPart != rightPart { return leftPart < rightPart ? -1 : 1 }
            }
            return 0
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
