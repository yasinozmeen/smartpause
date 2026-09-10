# Tanıtım görselleri

Setapp mağaza formatı (2560×1600): üstte tek cümlelik başlık, koyu gradyan zemin, MacBook çerçevesinde gerçek arayüz.
Kaynaklar `src/` altında: `*.html` şablonlar (Chrome headless ile render), `widget.png` / `panel.png` / `onboarding.png` gerçek pencere yakalamaları.

Yeniden üretmek: `src/` içindeki HTML'i `"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" --headless=new --screenshot=out.png --window-size=2560,1600 file.html` ile render et.
Video: `src/demo.html?t=<saniye>` her kare için render edilip ffmpeg ile birleştirildi (12 fps, 9 sn).
