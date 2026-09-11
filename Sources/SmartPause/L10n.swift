import Foundation

/// Arayüz dili. Ürün kararı (Yasin, 2026-09-11): varsayılan İngilizce; Türkçe seçilebilir.
enum Language: String, CaseIterable {
    case en, tr
    var title: String { self == .en ? "English" : "Türkçe" }
    /// Ondalık ayırıcı (2.6 s / 2,6 sn).
    var decimalSeparator: String { self == .en ? "." : "," }
}

/// Kullanıcıya görünen her metin buradan geçer. rawValue = İngilizce kaynak; `tr` sözlüğü Türkçe karşılık.
/// Kullanım: `L.ready.t` düz metin, `L.statusPlaying(name)` biçimli metin (%@ / %d).
enum L: String {
    // Genel
    case ready = "Ready"
    case ok = "OK"
    case open = "Open"
    case show = "Show"
    case quit = "Quit"
    case done = "Done"
    case continueBtn = "Continue"
    case settings = "Settings"
    case playing = "Playing"
    case paused = "Paused"

    // Tuş davranışı seçenekleri
    case modeSwitchKey = "Single press switches, double press plays/pauses"
    case modeSwitchTarget = "Press pauses, quick second press switches"
    case modeSilenceAll = "Press pauses, quick second press silences all"
    // Menü çubuğu simgeleri
    case iconCircle = "Circle"
    case iconPlain = "Plain"
    case iconWave = "Wave"
    case iconSpeaker = "Speaker"

    // Durum cümleleri (panel başlığı)
    case statusWaitingPermission = "Waiting for Accessibility permission"
    case statusDisabled = "Off — the key goes to the system"
    case statusPlaying = "%@ is playing"
    case statusPaused = "%@ paused"
    case statusWaitingKey = "Waiting for the key"
    case nothingYet = "Nothing yet"
    case secAgo = "%d s ago"
    case minAgo = "%d min ago"
    case hourAgo = "%d h ago"
    case lastEvent = "Last: %@, %@"

    // Panel
    case tabBehavior = "Behavior"
    case tabApps = "Apps"
    case tabSetup = "Setup"
    case helpTapLive = "Key listener is live"
    case helpNoPermission = "No Accessibility permission"
    case enabledTitle = "SmartPause enabled"
    case enabledDesc = "When off, the key goes straight to the system."
    case showWidgetTitle = "Show widget on key press"
    case showWidgetDesc = "Appears at the top right and shows what I did."
    case durationTitle = "How long the widget stays"
    case durationDesc = "Time on screen after a key press. Waits while the mouse is over it."
    case seconds = "%@ s"
    case memoryTitle = "How far back to remember"
    case memoryDesc = "Apps that played media within this window stay in the widget; double-click resumes them."
    case minutes = "%d min"
    case oneHour = "1 h"
    case blockMusicTitle = "Block Apple Music"
    case blockMusicDesc = "Closes it if it opens by itself. Never touches it when you open it."
    case keyBehaviorTitle = "Key behavior"
    case keyBehaviorDesc = "With several apps in the widget, what should play/pause do?"
    case menuIconTitle = "Menu bar icon"
    case menuIconDesc = "The mark shown in the menu bar."
    case loginTitle = "Launch at login"
    case loginDesc = "Shows up in the menu bar when your Mac starts."
    case languageTitle = "Language"
    case languageDesc = "Interface language."
    case appsIntro = "Who I can control. Yellow ones need a setting; click to see the step."
    case appsMissing = "An app that's not listed?"
    case requestSupport = "Request support →"
    case accessTitle = "Accessibility permission"
    case accessGranted = "Granted. I can hear the keys."
    case accessNeeded = "Required. System Settings › Privacy & Security."
    case automationTitle = "Automation permission"
    case automationDesc = "Asked once per app on first use."
    case browserJSTitle = "Browser JavaScript setting"
    case browserJSDesc = "Optional. If it's off, I hand the key to the system and it still works."
    case logTitle = "Log file"
    case logDesc = "~/Library/Logs/SmartPause.log — attach it when reporting a problem."
    case setupHelp = "Setup help"
    case pillNeedsSetting = "Needs setting"
    case pillOff = "Off"
    case pillNotInstalled = "Not installed"

    // Onboarding
    case stepAccess = "Accessibility"
    case stepTry = "Try it"
    case step1of3 = "Step 1 / 3 · Esc to skip"
    case step2of3 = "Step 2 / 3 · Optional"
    case step3of3 = "Step 3 / 3"
    case obPermTitle = "I need to hear the key"
    case obPermBody = "Catching the play/pause key needs macOS Accessibility permission. I don't record your keyboard; I only listen for media keys."
    case openSystemSettings = "Open System Settings"
    case continuesAuto = "Continues automatically once granted"
    case obAppsTitle = "Who I can control"
    case obAppsBody = "These are what I found on your Mac. Browsers need a small setting so I can pause video directly; if you skip it, I hand the key to the system and it still works."
    case showSetting = "Show %@ setting"
    case obTryTitle = "Try it now"
    case obTryBody = "Start Spotify or a YouTube tab, then press play/pause. You'll see what I did at the top right."
    case rightClickHint = "Right-click the icon for settings"
    case waiting = "waiting…"

    // Widget
    case hudRowHelp = "Click: make target · Double-click: play/pause"
    case cantHear = "I can't hear the key"
    case needAccess = "Accessibility permission required"
    case passedToSystem = "Handed the key to the system"

    // Ayar uyarısı (NSAlert)
    case singleSettingTitle = "One setting for %@"
    case worksWithout = "It works without it too: I hand the key to the system."

    // Router olayları (widget başlığı + günlük)
    case unknownPassthrough = "%@ not recognized → key handed to the system"
    case noAudio = "No audio, no target → passthrough"
    case notControllable = "%@ can't be controlled (JS permission off) → passthrough"
    case requestSupportHint = "Request support for this app"
    case targetIs = "Target: %@"
    case nextTrack = "Next track: %@"
    case prevTrack = "Previous track: %@"
    case trackFailed = "%@ couldn't change track"
    case trackPassthrough = "Track key → passthrough"
    case pausedX = "Paused: %@"
    case alsoPaused = "Also paused: %@"
    case pauseFailed = "%@ couldn't be paused"
    case resumed = "Resumed: %@"
    case resumeFailed = "%@ couldn't be resumed"
    case switched = "Switched: %@ is playing"
    case startFailed = "%@ couldn't be started"
    case targetMoved = "Target moved: %@ keeps playing, %@ paused"
    case switchHint = "Single press: switch to %@\nDouble press: play/pause %@"
    case againSwitch = "Press again to switch to %@"
    case againSilence = "Press again and I'll pause %@ too"

    // Adapter notları
    case chromiumSettingHint = "View › Developer › \"Allow JavaScript from Apple Events\" must be on"
    case safariSettingHint = "Develop › \"Allow JavaScript from Apple Events\" must be on (Settings › Advanced › Show Develop menu)"
    case notRunningNote = "not running; checked when the setting is on"
    case noWindow = "no window"

    /// Seçili dildeki metin.
    var t: String { Settings.language == .tr ? (L.tr[self] ?? rawValue) : rawValue }
    /// Biçimli metin (%@ / %d).
    func callAsFunction(_ args: CVarArg...) -> String { String(format: t, arguments: args) }

    static let tr: [L: String] = [
        .ready: "Hazır", .ok: "Tamam", .open: "Aç", .show: "Göster", .quit: "Çık", .done: "Bitti", .continueBtn: "Devam",
        .settings: "Ayarlar", .playing: "Çalıyor", .paused: "Duraklatıldı",
        .modeSwitchKey: "Tek basış geçir, çift basış başlat/durdur",
        .modeSwitchTarget: "Basış durdurur, hızlı ikinci basış geçirir",
        .modeSilenceAll: "Basış durdurur, hızlı ikinci basış hepsini susturur",
        .iconCircle: "Daire", .iconPlain: "Sade", .iconWave: "Dalga", .iconSpeaker: "Hoparlör",
        .statusWaitingPermission: "Erişilebilirlik izni bekleniyor", .statusDisabled: "Kapalı — tuş sisteme gidiyor",
        .statusPlaying: "%@ çalıyor", .statusPaused: "%@ duraklatıldı", .statusWaitingKey: "Tuşu bekliyorum",
        .nothingYet: "Henüz bir şey olmadı", .secAgo: "%d sn önce", .minAgo: "%d dk önce", .hourAgo: "%d sa önce", .lastEvent: "Son: %@, %@",
        .tabBehavior: "Davranış", .tabApps: "Uygulamalar", .tabSetup: "Kurulum",
        .helpTapLive: "Tuş yakalayıcı canlı", .helpNoPermission: "Erişilebilirlik izni yok",
        .enabledTitle: "SmartPause etkin", .enabledDesc: "Kapalıyken tuş doğrudan sisteme gider.",
        .showWidgetTitle: "Tuşa basınca widget göster", .showWidgetDesc: "Sağ üstte belirir, ne yaptığımı gösterir.",
        .durationTitle: "Widget ne kadar kalsın", .durationDesc: "Tuşa bastıktan sonra ekranda kalma süresi. Fare üstündeyken bekler.",
        .seconds: "%@ sn",
        .memoryTitle: "Ne kadar geriye hatırlayayım", .memoryDesc: "Bu süre içinde medya oynatan uygulamalar widget'ta kalır; çift tıkla sürdürürsün.",
        .minutes: "%d dk", .oneHour: "1 sa",
        .blockMusicTitle: "Apple Music'i engelle", .blockMusicDesc: "Kendiliğinden açılırsa kapatır. Sen açarsan karışmaz.",
        .keyBehaviorTitle: "Tuş davranışı", .keyBehaviorDesc: "Widget'ta birden çok uygulama varken play/pause ne yapsın?",
        .menuIconTitle: "Menü çubuğu simgesi", .menuIconDesc: "Menü çubuğunda görünen işaret.",
        .loginTitle: "Girişte başlat", .loginDesc: "Mac açılınca menü çubuğuna gelir.",
        .languageTitle: "Dil", .languageDesc: "Arayüz dili.",
        .appsIntro: "Kimleri kontrol edebildiğim. Sarı olanlar bir ayar istiyor; tıklayınca adımı gösteririm.",
        .appsMissing: "Listede olmayan bir uygulama mı?", .requestSupport: "Destek iste →",
        .accessTitle: "Erişilebilirlik izni", .accessGranted: "Verildi. Tuşları duyabiliyorum.", .accessNeeded: "Gerekli. Sistem Ayarları › Gizlilik ve Güvenlik.",
        .automationTitle: "Otomasyon izni", .automationDesc: "İlk kullanımda her uygulama için bir kez sorulur.",
        .browserJSTitle: "Tarayıcı JavaScript ayarı", .browserJSDesc: "İsteğe bağlı. Kapalıysa tuşu sisteme bırakırım, yine çalışır.",
        .logTitle: "Günlük dosyası", .logDesc: "~/Library/Logs/SmartPause.log — sorun bildirirken ekle.",
        .setupHelp: "Kurulum yardımı",
        .pillNeedsSetting: "Ayar gerekli", .pillOff: "Kapalı", .pillNotInstalled: "Yüklü değil",
        .stepAccess: "Erişilebilirlik", .stepTry: "Dene",
        .step1of3: "Adım 1 / 3 · Esc ile sonra", .step2of3: "Adım 2 / 3 · İsteğe bağlı", .step3of3: "Adım 3 / 3",
        .obPermTitle: "Tuşu duymam gerekiyor",
        .obPermBody: "Play/pause tuşunu yakalamak için macOS'un Erişilebilirlik izni gerekir. Klavyeni kaydetmem; yalnız medya tuşlarını dinlerim.",
        .openSystemSettings: "Sistem Ayarları'nı aç", .continuesAuto: "Verdiğin anda kendiliğinden devam eder",
        .obAppsTitle: "Kimleri kontrol edebilirim",
        .obAppsBody: "Bunlar Mac'inde bulduklarım. Tarayıcılarda videoyu doğrudan durdurabilmem için küçük bir ayar gerekir; istemezsen tuşu sisteme bırakırım, yine çalışır.",
        .showSetting: "%@ ayarını göster",
        .obTryTitle: "Şimdi dene",
        .obTryBody: "Spotify'ı ya da bir YouTube sekmesini başlat, sonra play/pause tuşuna bas. Ne yaptığımı sağ üstte göreceksin.",
        .rightClickHint: "Ayarlar için simgeye sağ tıkla", .waiting: "bekliyorum…",
        .hudRowHelp: "Tek tık: hedef yap · Çift tık: başlat/durdur",
        .cantHear: "Tuşu duyamıyorum", .needAccess: "Erişilebilirlik izni gerekli", .passedToSystem: "Tuşu sisteme bıraktım",
        .singleSettingTitle: "%@ için tek ayar", .worksWithout: "Bu ayar olmadan da çalışır: tuşu sisteme bırakırım.",
        .unknownPassthrough: "%@ tanınmıyor → tuş sisteme bırakıldı", .noAudio: "Ses yok, hedef yok → passthrough",
        .notControllable: "%@ kontrol edilemiyor (JS izni kapalı) → passthrough", .requestSupportHint: "Bu uygulama için destek iste",
        .targetIs: "Hedef: %@", .nextTrack: "Sonraki parça: %@", .prevTrack: "Önceki parça: %@", .trackFailed: "%@ parça değiştiremedi",
        .trackPassthrough: "Parça tuşu → passthrough",
        .pausedX: "Durduruldu: %@", .alsoPaused: "Bu da durduruldu: %@", .pauseFailed: "%@ durdurulamadı",
        .resumed: "Sürdürüldü: %@", .resumeFailed: "%@ sürdürülemedi",
        .switched: "Geçildi: %@ çalıyor", .startFailed: "%@ başlatılamadı",
        .targetMoved: "Hedef geçti: %@ sürüyor, %@ durdu",
        .switchHint: "Tek basış: %@'e geç\nÇift basış: %@ başlat/durdur",
        .againSwitch: "Bir daha basarsan %@'e geçerim", .againSilence: "Bir daha basarsan %@'i de durdururum",
        .chromiumSettingHint: "Görünüm › Geliştirici › \"Apple Events'ten JavaScript'e izin ver\" açılmalı",
        .safariSettingHint: "Geliştir › \"Apple Events'ten JavaScript'e İzin Ver\" açılmalı (Ayarlar › İleri Düzey › Geliştir menüsü)",
        .notRunningNote: "kapalı, ayar açıkken kontrol edilir", .noWindow: "pencere yok",
    ]
}
