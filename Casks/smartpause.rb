cask "smartpause" do
  version "0.1.0"
  sha256 "7e32839934952d07e4f2762752a0a00072166659c0c99fc092d6457e0ea0c14c"

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
