# Carlo Burger & Bi Hatıra Kontrol — CLAUDE.md

Bu depo, Carlo Burger ve Bi Hatıra işletmelerinin dijital checklist uygulamasıdır. Personel telefondan
checklist doldurur, eksikler "eksik iş" olur, müdür onaylar; yönetici rapor alır.

## Benimle çalışırken

- Benimle **Türkçe** konuş. Teknik terimleri sade anlat; ben yazılımcı değilim, işletme sahibiyim.
- Çoğunlukla telefondan yazıyorum. Kısa, adım adım ve net cevap ver.
- Bir değişikliği bitirince ne değiştiğini, nasıl göreceğimi ve neyi denemediğini söyle.
- Benden SQL çalıştırmamı isteme: Supabase bağlı, gerekiyorsa sen çalıştır, dosyasını da depoya koy.
- **Netlify kullanmıyoruz.** Yayın yalnızca GitHub Pages.
- Şifre, e-posta gibi bilgileri bu dosyaya ya da koda yazma.

## Yayın

- Canlı adres: https://cagrcihan-create.github.io/kontrol/
- `main` dalına push = GitHub Pages birkaç dakikada yayınlar. Ayrı dal/PR açmadan doğrudan `main`'e
  push ediyoruz (benim onayımla).
- Telefonlar eski sürümü ~10 dk önbellekte tutar. "Gelmedi" dersem önce bunu düşün; çözüm:
  uygulamayı kapatıp açmak ya da adrese `?v=N` eklemek.
- Commit mesajları Türkçe.

## Dosyalar

| Dosya | Ne |
|---|---|
| `index.html` | **Uygulamanın tamamı** (~1400 satır): HTML + CSS + JS + gömülü checklist verisi tek dosyada |
| `TEKRAR_YAP.sql` | `send_back_items` RPC'si (Supabase'e uygulandı) |
| `TOPLU_ONAY.sql` | `review_missing_task` yöneticiye açıldı + `approve_missing_tasks` toplu onay (uygulandı) |
| `SON_SAAT.sql` | `checklist_templates.deadline` sütunu — **henüz uygulanmadı** (aşağıya bak) |

E-posta bildirimi kapalı (26.11.2026): checklist gönderilince mail gitmez, `send-checklist-email` fonksiyonu çağrılmaz. Benim isteğimle kapattık; geri açma.

Başka build adımı, paket, framework yok. Kütüphaneler ilk kullanımda jsDelivr'den yüklenir:
pdfmake 0.2.23 (PDF üretimi), pdfjs-dist 4.10.38 legacy (uygulama içi PDF görüntüleyici), Excel için SheetJS.

## index.html içinde

- `<script type="application/json" id="checklist-data">`: yerleşik checklistler (JSON dizi). Her biri
  `{key, business, title, deadline?, from?, stock?, sections:[{title, items:[...]}]}`.
  - Madde ya düz metin ya da nesne: `{label, fields:[...], buttons?, repeat?}`.
  - Alan (`fields`): `{key, label, type: 'number'|'date'|'select', unit?, optional?, blank?, hint?, skipIfZero?}`
    - `optional`: boş bırakılabilir · `blank`: tarih bugünle dolu gelmez · `skipIfZero: '<alan>'`: o alan 0 ise bu alan istenmez ve özete yazılmaz.
  - `repeat: {countKey, key, label, type, max}`: girilen adet kadar alan açar (ör. her peynir tabağı için tarih).
  - `buttons: ['Tamam','Eksik']`: ölçümlü maddelerde varsayılan "Hazırlandı/Hazırlanamadı" yerine.
  - `deadline: 'SS:DD'`: son gönderim saati; geçince müdür ekranında uyarı. Gün **05.00'te** başlar (02.00 kapanış önceki güne sayılır).
  - `from: 'YYYY-MM-DD'`: raporlar bu tarihten önceki günleri "gönderilmedi" saymaz. Yeni listeye eklenirken bugünün tarihini koy.
  - `stock: true`: son adımda "eksik stok" ve "zayi" kutuları (ikisi de zorunlu, yoksa "Yok").
- Durum nesnesi `S`; ekranlar `view*()` fonksiyonları; düğmeler `data-a="..."` → `ACTIONS` haritası;
  form alanları `data-i="..."` → `input` olay işleyicisi.
- Sekmeler: Listeler, Eksik işler, Onaylar, Kayıtlar, Rapor (Rapor yalnızca yönetici/admin).
- Rapor hesabı `reportModel()` (ekran ve PDF ortak), PDF'ler `pdfRecord`/`pdfDoc`/`reportDoc`, görüntüleyici `viewPdf`.

## Supabase

- Proje: `sxgwvubmdbworuyknipa` (organizasyon "carlo bi hatıra"). Uygulama REST/RPC'ye doğrudan fetch ile bağlanır.
- Tablolar:
  - `profiles` (role: `personel` | `mudur` | `admin`; kodda `yonetici` de geçer; `approved`, `business`)
  - `checklist_records` (answers jsonb `"bölüm-madde"` anahtarlı, labels, stock, waste, status: `Onay bekliyor` | `Onaylandı` | `Düzeltme istendi`)
  - `checklist_missing_tasks` (status: `open` | `pending_approval` | `approved` | `rejected`; `(record_id,item_key)` benzersiz)
  - `checklist_templates` (düzenleme ekranından kaydedilen listeler)
- Tetikleyici: kayıt eklenince `Eksik` maddeler için eksik iş açılır (`create_missing_tasks_for_record`).
- RPC'ler: `review_record`, `send_back_items` (müdür seçili maddeleri tekrar yaptırır), `complete_missing_task`
  (yalnızca personel), `review_missing_task` (müdür ve yönetici), `approve_missing_tasks` (toplu onay; yalnızca `pending_approval` işler).
- Eksik işler uygulamada gizlenir, **silinmez**: onaylananlar 48 saat sonra; onaylanmamış bir işte 2 gündür hareket yoksa (açılma/tamamlanma/geri gönderme) o da. Veritabanında ve raporlarda durur.
- RLS: personel yalnızca **kendi** kayıtlarını görür. Bu yüzden "gecikti" uyarıları ve raporlar yalnızca müdür/yönetici içindir.

### Önemli tuzak: şablon kopyaları

Düzenleme ekranından kaydedilen bir liste `checklist_templates`'e yazılır ve **koddaki yerleşik listenin
önüne geçer**. Koddaki bir listeyi değiştirmeden önce mutlaka bak:

```sql
select key, active, updated_by, updated_at from checklist_templates order by updated_at desc;
```

O liste için satır varsa değişikliği o satırın `sections` alanına da uygula (ör. `jsonb_set`), yoksa telefonda görünmez.
Şu an: `sabah_mutfak` aktif kopya (ben ilk bölümden "Çay kazanı" maddesini çıkardım);
`acilis`, `taha`, `bi_acilis` pasif (yayından kaldırıldı).

### Listeyi kaldırma

Silme yok. `checklist_templates`'e `active = false` satırı yaz (yerleşik `sections` ile birlikte). Geçmiş kayıtlar ve raporlar korunur.

### `deadline` sütunu

`SON_SAAT.sql` uygulanmadı; `checklist_templates`'te `deadline` sütunu yok. Son saatler koddaki yerleşik
veriden gelir. Düzenleme ekranında saat kaydedilirse uygulama saatsiz kaydeder ve uyarır.

## Kurallar

- **Veritabanındaki kayıtları asla silme.** SQL değişiklikleri yalnızca ekleyen/geri alınabilir olsun;
  her SQL'i ayrıca depoya `.sql` dosyası olarak koy.
- Çalışan özellikleri bozma; sistemi sıfırdan yazma.
- Gerçek veride RPC denemesi gerekirse işlemi geri al: `do $$ ... raise exception 'TEST_GERI_AL ...' $$`.
- Yeni checklist PDF'ten gelirse: kâğıttaki "eksik var/yok", "düzeltildi" kutuları ve imzalar eklenmez;
  bunları uygulamanın Eksik → eksik iş → müdür onayı akışı karşılar. Zayi tablosu `stock: true` ile son adıma gider.

## Test

Otomatik test yok. Değişiklikten sonra:

1. `index.html` içindeki ana `<script>`'i çıkarıp `node --check` ile sözdizimini denetle.
2. Playwright (Chromium, 400×900 telefon boyutu) ile sayfayı aç; Supabase isteklerini `page.route` ile
   sahte verilerle karşıla (`/auth/v1/user`, `/rest/v1/profiles`, `checklist_records` …), oturumu
   `localStorage.kontrol_oturum` ile ver. CDN kütüphanelerini yerel `node_modules`'tan sun.
3. İlgili rol(ler)le (personel / mudur / admin) akışı baştan sona yürüt, ekran görüntüsüne bak.
4. Gerçek telefonda denenmediyse bunu bana söyle.
