# PRO Batch v0.2

Sahnedeki tum kameralari (V-Ray Physical, Physical, Target/Free) sirayla render eden 3ds Max paneli. Gece boyunca gozetimsiz render icin tasarlandi.

## Kurulum

3ds Max > **Scripting > Run Script...** > `ProBatch.ms`

## Ozellikler

- Sahnedeki tum kameralari listeler, hepsi secili gelir.
- Her kamera **aktif Render Setup ile (F9 ile ayni yol)** render edilir.
- **Kayit V-Ray VFB'den yapilir:** Display Correction, exposure, LUT, denoiser dahil; VFB'de ne gorurseniz dosyada o vardir.
- Alpha istege bagli. Kapaliyken PNG/TIF, renklere dokunulmadan siyah zeminli (alpha'siz) kaydedilir.
- Cikti: `SahneAdi_KameraAdi.png` (png / jpg / exr / tif / tga). Animasyonda kare kare: `SahneAdi_KameraAdi_0000.png`.
- Hata veren kamera atlanir; `PRO_Batch_rapor.txt` her kameranin suresini ve sonucunu yazar.
- Istege bagli: is bitince bilgisayar 5 dk sonra kapanir (iptal: `shutdown /a`).
- Is bitince Render Setup, aktif viewport ve zaman cizelgesi eski haline doner.

Hedef: 3ds Max 2024+ / V-Ray.

## Surum notlari

### v0.2 (2026-11-20)
- Duzeltme: v0.1, 3ds Max'in kendi cikti kaydini kullaniyordu; VFB duzeltmeleri uygulanmadan (koyu) ve seffaf zeminle kaydediyordu. Artik kayit V-Ray VFB'den yapiliyor.
- Test: 3ds Max 2026 + V-Ray 7 update 2 hotfix 2, 5 kamera, 4000x2250, 5 tamam / 0 hata, 2 dk 36 sn. Ciktilar VFB ile ayni parlaklikta, RGB.

### v0.1 (2026-11-20)
- Ilk surum.
