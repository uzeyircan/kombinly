# Kombinly — Antigravity Premium 3D Try-On Geliştirme Görev Dosyası

## 1. Projenin ana hedefi

Bu proje bir Flutter + Supabase mobil kombin uygulamasıdır. Kullanıcılar kendi gardıroplarındaki kıyafetlerin fotoğrafını çekecek veya galeriden yükleyecek. Uygulama bu kıyafetleri kategori, renk, mevsim, kullanım amacı ve ortam bilgilerine göre analiz edecek; kullanıcıya toplantı, gezi, date, günlük kullanım, özel gün gibi senaryolara göre kombin önerecek.

En kritik hedef: Uygulama kıyafetleri sadece manken görselinin üstüne 2D sticker gibi koymamalı. Premium his veren, kıyafetin 3D mankene gerçekten giydirilmiş gibi göründüğü bir deneyim hedefleniyor.

Mevcut sistemde kıyafetler büyük ölçüde 2D overlay mantığıyla avatar/manken üzerine yerleştiriliyor. Bu görüntü zayıf kalır. Hedef; gerçek 3D manken, kamera hareketi, mesh/slot mantığı, kıyafet katmanları, derinlik, ışık, gölge ve perspektif hissi olan premium bir try-on deneyimidir.

---

## 2. Mevcut proje hakkında kısa teknik durum

Proje Flutter ile yazılmıştır.

Kullanılan ana teknolojiler:

- Flutter
- Dart
- Supabase Auth
- Supabase Database
- Supabase Storage
- Supabase Edge Function / image processing akışı
- Image picker
- Gardırop sistemi
- Kıyafet yükleme sistemi
- Arka plan kaldırılmış kıyafet görselleri
- Outfit/studio sayfaları
- Avatar canvas / placement sistemi

Projede şu yapılar mevcut:

- `lib/features/wardrobe/`
  - Kıyafet ekleme, listeleme, düzenleme
  - `ClothingItem` modeli
  - `GarmentProcessor`
  - `ReprocessClothingService`

- `lib/features/avatar/`
  - Avatar slot modelleri
  - Smart placement
  - Fit engine
  - Snap engine
  - Avatar canvas
  - Placed clothing item
  - Mannequin manifest yapısı

- `lib/features/outfit/`
  - Günlük kombin üretimi
  - Kayıtlı kombinler
  - Try-on studio
  - `ThreeDMannequinStage`

- `lib/features/ai_try_on/`
  - AI try-on servisleri ve sayfası

Önemli mevcut dosyalar:

- `lib/features/outfit/presentation/pages/try_on_studio_page.dart`
- `lib/features/outfit/presentation/widgets/three_d_mannequin_stage.dart`
- `lib/features/avatar/presentation/widgets/avatar_canvas.dart`
- `lib/features/avatar/presentation/widgets/placed_clothing_item.dart`
- `lib/features/avatar/domain/services/smart_placement_service.dart`
- `lib/features/avatar/domain/services/fit_engine.dart`
- `lib/features/avatar/domain/services/snap_engine.dart`
- `lib/features/avatar/domain/models/mannequin_manifest.dart`
- `assets/mannequin/standard_mannequin.v1.json`

---

## 3. Şu anki ana problem

Mevcut uygulama “3D” adını taşısa bile gerçek anlamda 3D giydirme yapmıyor. `ThreeDMannequinStage` içinde 3D manken altyapısına hazırlık var ancak gerçek GLB/3D model render akışı bağlanmamış. Şu anki görüntü daha çok 2D avatar canvas üzerine kıyafet görseli koyma yaklaşımına yakın.

Bu haliyle premium ürün algısı zayıf olur.

Net hedef:

> Kıyafetler mankenin üstüne yapıştırılmış gibi değil, mankenin vücuduna gerçekten oturmuş, perspektife uyan, ışık/gölgeyle bütünleşen ve 3D sahnede giyilmiş gibi görünmelidir.

---

## 4. Antigravity için çalışma talimatı

Bu projeyi geliştirirken mevcut çalışan yapıyı bozma. Kod değişikliklerini adım adım yap. Önce mimariyi oku, sonra küçük ama sağlam aşamalarla ilerle.

Her aşamada şu kurallara uy:

1. Mevcut Flutter projesini analiz et.
2. Var olan dosyaları rastgele silme veya yeniden yazma.
3. Önce çalışan sistemi koru.
4. 2D overlay sistemini hemen tamamen çöpe atma; bunu V1 fallback olarak tut.
5. Premium 3D try-on sistemini ayrı ve kontrollü şekilde geliştir.
6. Her aşamadan sonra `flutter analyze` ve mümkünse `flutter run` ile hata kontrolü yap.
7. Büyük değişiklikleri tek seferde yapma.
8. Her dosyada neden değişiklik yaptığını açıkça belirt.

---

## 5. Hedef ürün deneyimi

Kullanıcı akışı şöyle olmalı:

1. Kullanıcı kıyafet fotoğrafı çeker veya galeriden yükler.
2. Uygulama kıyafetin arka planını kaldırır.
3. Uygulama kıyafetin kategorisini alır veya tahmin eder:
   - Üst giyim
   - Alt giyim
   - Ayakkabı
   - Dış giyim
   - Elbise
   - Aksesuar
4. Kullanıcı kıyafete şu bilgileri ekler:
   - Renk
   - Mevsim
   - Kullanım amacı
   - Ortam: toplantı, gezi, date, iş, günlük, özel gün vb.
5. Uygulama gardıroptaki ürünleri bu bilgilere göre eşleştirir.
6. Uygulama kombin önerir.
7. Kullanıcı kombinleri 3D manken üzerinde görür.
8. Kıyafetler mankenin vücuduna gerçekçi şekilde oturur.
9. Kullanıcı mankeni döndürebilir, yakınlaştırabilir ve premium stüdyo görünümünde kombini inceleyebilir.

---

## 6. V1 için gerçekçi teknik hedef

Tam gerçek 3D kıyafet simülasyonu, sadece 2D fotoğraftan doğrudan kusursuz şekilde yapılamaz. Bu yüzden V1 hedefi gerçekçi ve uygulanabilir olmalı.

V1 hedefi:

- Gerçek 3D manken GLB modeli eklemek
- Flutter içinde 3D model görüntülemek
- Kamera/orbit/zoom kontrolü sağlamak
- Kıyafetleri kategoriye göre doğru vücut bölgelerine bağlamak
- Kıyafet görsellerini 3D hissi verecek şekilde deform/perspektif/maskeleme/gölge ile göstermek
- 2D sticker hissini azaltmak
- Premium stüdyo UI oluşturmak

V1’de tam fizik tabanlı kumaş simülasyonu şart değildir. Ancak görsel kalite “üstüne resim koyulmuş” gibi kalmamalı.

---

## 7. Önerilen geliştirme aşamaları

### Aşama 1 — Proje analizi ve temizlik

Yapılacaklar:

- Proje klasörünü aç.
- `pubspec.yaml` dosyasını kontrol et.
- `lib/features/avatar`, `lib/features/outfit`, `lib/features/wardrobe`, `lib/features/ai_try_on` yapılarını incele.
- Mevcut `ThreeDMannequinStage` dosyasının gerçek 3D render yapmadığını doğrula.
- Mevcut 2D sistemi fallback olarak koru.

Beklenen çıktı:

- Mevcut sistemin kısa teknik özeti
- Hangi dosyaların değişeceği listesi
- İlk küçük uygulanabilir plan

---

### Aşama 2 — Gerçek 3D manken altyapısı

Yapılacaklar:

- Flutter için uygun 3D görüntüleme paketini araştır ve ekle.
- Tercih edilebilecek seçenekler:
  - `model_viewer_plus`
  - `flutter_3d_controller`
  - uygun başka GLB destekli paket
- `assets/mannequin/` altına gerçek bir `.glb` manken modeli bağlanacak şekilde yapı hazırla.
- `pubspec.yaml` içine GLB asset yolu eklenecek.
- `ThreeDMannequinStage` gerçek 3D model gösteren hale getirilecek.

Beklenen çıktı:

- 3D manken sahnede görünecek.
- Kullanıcı modeli döndürebilecek.
- Zoom/orbit hissi olacak.
- Eski 2D canvas fallback olarak kalacak.

---

### Aşama 3 — Mannequin manifest sistemini güçlendirme

Mevcut `standard_mannequin.v1.json` manifest sistemi korunmalı ve genişletilmeli.

Manifest şunları tutmalı:

- Manken modeli asset yolu
- Cinsiyet / vücut tipi
- Boy oranları
- Slot bölgeleri
- Üst beden slotu
- Alt beden slotu
- Ayakkabı slotu
- Dış giyim slotu
- Elbise slotu
- Aksesuar slotları
- Kamera başlangıç pozisyonu
- Işık bilgisi
- Premium render ayarları

Örnek alanlar:

```json
{
  "id": "standard_female_v1",
  "displayName": "Standard Premium Mannequin",
  "modelPath": "assets/mannequin/standard_female_v1.glb",
  "hasRealModel": true,
  "camera": {
    "initialYaw": 0,
    "initialPitch": 0,
    "initialZoom": 1.0
  },
  "garmentSlots": [
    {
      "id": "upper_body",
      "category": "Top",
      "anchor": "chest",
      "zIndex": 30
    },
    {
      "id": "lower_body",
      "category": "Bottom",
      "anchor": "hips_legs",
      "zIndex": 20
    },
    {
      "id": "shoes",
      "category": "Shoes",
      "anchor": "feet",
      "zIndex": 10
    }
  ]
}
```

---

### Aşama 4 — Kıyafetlerin “giyilmiş gibi” görünmesi için hibrit sistem

Sadece kullanıcının yüklediği 2D fotoğrafla tam 3D mesh üretmek zor ve V1 için ağırdır. Bu yüzden hibrit yaklaşım kullanılmalı.

Hibrit yaklaşım:

- 3D manken gerçek olacak.
- Kıyafet görseli arka plansız PNG olacak.
- Kıyafet, kategoriye göre 3D mankenin ilgili bölgesine map edilecek.
- Kıyafet görseli düz resim gibi durmayacak; perspektif, crop, scale, warp, maske, gölge ve ışık efektiyle mankenin üstündeymiş gibi gösterilecek.
- Mümkünse kıyafet için depth/normal hissi veren shader benzeri efektler uygulanacak.

V1’de hedef:

- Üst giyim omuz/göğüs bölgesine oturmalı.
- Alt giyim bel/bacak hizasına oturmalı.
- Ayakkabı ayak bölgesine oturmalı.
- Dış giyim üst giyimin üst katmanında görünmeli.
- Kıyafetler vücut oranına göre fazla küçük veya fazla büyük durmamalı.

---

### Aşama 5 — Premium Try-On Studio UI

`try_on_studio_page.dart` premium hale getirilmeli.

Hedef UI:

- Siyah/gri/lacivert premium arka plan
- Ortada büyük 3D manken sahnesi
- Alt bölümde kıyafet seçim carousel’i
- Sağ/sol küçük kontrol paneli
- Kamera döndürme ve zoom kontrolleri
- “Studio 2D” ve “Premium 3D” ayrımı
- Kombin bilgisi kartı
- Mevsim/ortam/date/toplantı/gezi etiketleri
- Kaydet butonu
- AI try-on veya premium render butonu

Dikkat:

- Uygulama ucuz demo gibi görünmemeli.
- Kartlar, gölgeler, gradient, cam efekti ve modern spacing kullanılmalı.
- Mobil ekranlarda taşma olmamalı.

---

### Aşama 6 — Kullanım amacı ve mevsim bazlı kombin önerisi

Kıyafetlerde şu alanlar kullanılmalı:

- category
- color
- season
- occasion
- image_url
- processed_image_url
- aspect_ratio
- fit_profile

Kombin önerirken:

- Mevsim uyumu kontrol edilmeli.
- Ortam uyumu kontrol edilmeli.
- Renk uyumu basit kurallarla yapılmalı.
- Eksik kategori varsa kullanıcıya bildirilmeli.
- Örneğin toplantı için spor ayakkabı + çok casual üst önerisi zayıf sayılmalı.

Örnek senaryo:

- Kullanıcı: “Date / İlkbahar / Akşam” seçer.
- Uygulama: şık ama fazla resmi olmayan üst + uyumlu alt + ayakkabı önerir.
- Sonuç: 3D manken üzerinde premium kombin görünümü.

---

### Aşama 7 — AI Try-On sistemini doğru konumlandırma

Mevcut `ai_try_on` modülü incelenmeli.

AI try-on iki şekilde konumlandırılabilir:

1. Canlı/etkileşimli 3D manken deneyimi
2. Kullanıcının seçtiği kombinden premium render/görsel üretme

V1 için öneri:

- Canlı ekranda hibrit 3D manken göster.
- Ek olarak “Premium Render Oluştur” butonu ekle.
- Bu buton seçili kombin için daha gerçekçi tek kare AI try-on çıktısı üretsin.

Bu ayrım önemli:

- 3D sahne: kullanıcı etkileşimi için
- AI render: yüksek kalite görsel çıktı için

---

## 8. Veritabanı / model geliştirme önerisi

`clothes` tablosunda mevcut alanlar korunmalı. Gerekirse şu alanlar eklenebilir:

- `garment_slot`
- `fit_confidence`
- `render_profile`
- `depth_hint`
- `silhouette_mask_url`
- `normal_map_url`
- `processed_quality_score`
- `manual_adjust_required`

Ama önce mevcut sistemi kırmadan ilerle. DB değişikliği gerekiyorsa SQL migration ayrı verilmeli.

---

## 9. Kabul kriterleri

Bu görev başarılı sayılmak için şu kriterler sağlanmalı:

- Uygulama çalışmaya devam etmeli.
- Kullanıcı gardırobuna kıyafet ekleyebilmeli.
- Kıyafetler Supabase’den yüklenebilmeli.
- Try-on studio açılmalı.
- Gerçek 3D manken sahnede görünmeli.
- Kullanıcı mankeni döndürebilmeli veya 3D hissi almalı.
- Kıyafetler sadece düz sticker gibi görünmemeli.
- Kıyafetler kategoriye göre doğru vücut bölgesine oturmalı.
- 2D fallback bozulmamalı.
- Premium UI hissi artmalı.
- `flutter analyze` ciddi hata vermemeli.

---

## 10. Net uyarı

Bu uygulamanın değerli tarafı gardırop + kişisel kombin + premium try-on deneyimidir. Eğer kıyafetler sadece manken görselinin üstüne koyulursa ürün zayıf kalır. Bu yaklaşım demo gibi görünür ve premium algıyı öldürür.

Bu yüzden geliştirme hedefi şudur:

> “Kıyafeti avatarın üstüne koy” değil; “kıyafeti 3D mankene giydirilmiş gibi göster.”

Bütün geliştirme kararları bu hedefe göre alınmalı.

---

## 11. Antigravity’den istenecek ilk görev

Antigravity’ye ilk verilecek görev şu olmalı:

> Bu Flutter projesini analiz et. Mevcut try-on sistemi şu an gerçek 3D giydirme yapmıyor, daha çok 2D overlay/sticker mantığında çalışıyor. Önce mevcut `try_on_studio_page.dart`, `three_d_mannequin_stage.dart`, `avatar_canvas.dart`, `placed_clothing_item.dart`, `mannequin_manifest.dart` ve `standard_mannequin.v1.json` dosyalarını incele. Sonra çalışan sistemi bozmadan gerçek 3D manken altyapısı için uygulanabilir V1 planı çıkar. Ardından ilk adım olarak 3D manken GLB asset desteğini ve sahne yapısını ekle. 2D sistemi fallback olarak koru. Her değişiklikten sonra `flutter analyze` ile kontrol et.

---

## 12. Öncelik sırası

1. Projeyi çalıştır ve mevcut hataları tespit et.
2. 3D manken asset/render altyapısını bağla.
3. 2D fallback sistemini koru.
4. Try-on studio UI’ını premium hale getir.
5. Kıyafet slot/placement sistemini güçlendir.
6. Kıyafetlerin sticker gibi durmasını azaltacak görsel iyileştirmeleri ekle.
7. Kombin önerisini mevsim/ortam/date/toplantı/gezi gibi bağlamlarla geliştir.
8. AI premium render akışını ayrı buton olarak konumlandır.

