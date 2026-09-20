cask "smartpause" do
  version "0.2.3"
  sha256 "90f91591189b5feead18077ad9941a044379786f6dc1120c2e1b7c6caf949690"

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
