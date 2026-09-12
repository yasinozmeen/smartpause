cask "smartpause" do
  version "0.2.1"
  sha256 "2b8e5e52feb79337e2eb489753aed4adde5a963f9a03da946fa04bb0246e0fda"

  url "https://github.com/yasinozmeen/smartpause/releases/download/v#{version}/SmartPause-#{version}.zip"
  name "SmartPause"
  desc "Play/pause tuşunu o an gerçekten ses çıkaran uygulamaya yönlendiren menü bar aracı"
  homepage "https://github.com/yasinozmeen/smartpause"

  depends_on macos: :sonoma

  app "SmartPause.app"

  caveats <<~EOS
    SmartPause'un çalışması için Erişilebilirlik izni gerekir:
    Sistem Ayarları › Gizlilik ve Güvenlik › Erişilebilirlik › SmartPause
  EOS

  zap trash: "~/Library/Preferences/dev.smartpause.app.plist"
end
