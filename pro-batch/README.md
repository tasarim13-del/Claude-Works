# PRO Batch v0.1

Sahnedeki tum kameralari (V-Ray Physical, Physical, Target/Free) sirayla render eden 3ds Max paneli. Gece boyunca gozetimsiz render icin tasarlandi.

## Kurulum

3ds Max > **Scripting > Run Script...** > `ProBatch.ms`

## Ozellikler

- Sahnedeki tum kameralari listeler, hepsi secili gelir.
- Her kamera **aktif Render Setup ile (F9 ile ayni yol)** render edilir: V-Ray ayarlari, VFB, render element'leri aynen kullanilir. Is bitince Render Setup ve aktif viewport eski haline doner.
- Cikti: `SahneAdi_KameraAdi.png` (png / jpg / exr / tif / tga).
- Istege bagli cozunurluk degistirme, animasyon araligi, V-Ray VFB'den renk duzeltmeli ayri kayit.
- Hata veren kamera atlanir; `PRO_Batch_rapor.txt` her kameranin suresini ve sonucunu yazar.
- Istege bagli: is bitince bilgisayar 5 dk sonra kapanir (iptal: `shutdown /a`).
- Hizli Test: ilk secili kamerayi %25 cozunurlukte render eder.

Hedef: 3ds Max 2024+ / V-Ray.

## Surum notlari

### v0.1 (2026-11-20)
- 3ds Max 2026 + V-Ray 7 update 2 hotfix 2 ile test edildi: 5 kamera, 4000x2250, 5 tamam / 0 hata, toplam 3 dk 21 sn.
- MAXScript `render()` yerine aktif Render Setup kullanildi (V-Ray ayarlarinin atlanmamasi icin).
