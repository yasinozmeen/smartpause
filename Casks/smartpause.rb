cask "smartpause" do
  version "0.1.0"
  sha256 :no_check # release script gerçek sha256 ile doldurur

  url "https://github.com/yasinozmeen/smartpause/releases/download/v#{version}/SmartPause-#{version}.zip"
  name "SmartPause"
  desc "Play/pause tuşunu o an gerçekten ses çıkaran uygulamaya yönlendiren menü bar aracı"
  homepage "https://github.com/yasinozmeen/smartpause"

  depends_on macos: ">= :sonoma"

  app "SmartPause.app"

  caveats <<~EOS
    SmartPause'un çalışması için Erişilebilirlik izni gerekir:
    Sistem Ayarları › Gizlilik ve Güvenlik › Erişilebilirlik › SmartPause
  EOS

  zap trash: "~/Library/Preferences/dev.smartpause.app.plist"
end
