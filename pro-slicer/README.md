# PRO Slicer v0.1

3ds Max icin MaxScript araci. Secili geometrileri X/Y/Z eksenlerinde kup grid'e boler, topolojiyi temizler ve Low/High poly ciktilar uretir.

## Kurulum

- 3ds Max > **Scripting > Run Script...** > `ProSlicer.ms`
- Kalici kullanim icin dosyayi `<3ds Max>\scripts\Startup\` klasorune kopyalayin ve MAXScript Listener'a `PSOpen()` yazin.

## Ozellikler

1. **Dilimleme:** Hucre sayisi veya hucre boyutu ile 3 eksende kup grid. Her kesit duzlemi kendi duz kapagini alir.
2. **Temizlik:** Weld, yalniz vertex silme, normal birlestirme, auto smooth.
3. **Cikti (LOD):** `_MID` (temiz), `_LP` (ProOptimizer), `_HP` (Quadify + TurboSmooth). LOD dilimlemeden once uygulanir, parca sinirlari birbirine tam oturur.
4. **Spline > Mesh:** Grid kapak + segment + Quadify ile deformasyona (Bend/FFD/Twist) hazir mesh.

Ayarlar `plugcfg\ProSlicer.ini` dosyasina otomatik kaydedilir; ayri setler kaydedilip yuklenebilir. Tum islem tek Ctrl+Z ile geri alinir, ciktilar `PRO_Slicer_*` katmanlarina gider.

## Surum notlari

### v0.1 (2026-11-18)
- Ilk surum, 3ds Max 2026'da test edildi.
- Duzeltmeler: case satiri syntax hatasi; kesit basina duz kapak (onceden tek, duz olmayan n-gon); ProOptimizer KeepNormals kapatildi (koyu golgelenme); ayar yukleme hatasi; hiz 115 sn > 2,3 sn.
