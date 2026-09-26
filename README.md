# Palet Pelaminan

Web sederhana (satu file `index.html`, tanpa instalasi) untuk mencocokkan warna acara pernikahan dan memberi skor apakah semuanya serasi.

## Cara pakai

Buka `index.html` langsung di browser.

1. Pilih elemen di kiri: panggung & dekorasi, bunga, gaun pengantin wanita, busana pengantin pria, seserahan, seragam keluarga, bridesmaid / pagar ayu, panitia / among tamu. Elemen lain bisa ditambah (mis. undangan, souvenir).
2. Atur warnanya dengan pemilih segitiga:
   - **Cincin + segitiga**: cincin untuk rona, segitiga untuk mencampur rona murni dengan putih dan hitam.
   - **Segitiga RGB**: tiap sudut adalah Merah, Hijau, Biru, ditambah slider kecerahan (V).
   - Bisa juga lewat slider R/G/B, kode hex, atau warna populer pernikahan.
3. Pratinjau pelaminan menggambar panggung (gebyok berlapis, pilar, tirai, rangkaian bunga), pengantin, orang tua dengan beskap dan kebaya, pagar ayu, meja seserahan, dan among tamu sesuai warna pilihan. Klik bagian gambar untuk langsung memilih elemennya.
4. Lihat skornya (0–100) dan status tiap elemen: **Match**, **Hampir**, atau **Tidak match**. Kolom saran memberi warna pengganti yang menaikkan skor.

## Cara penilaian

| Kriteria | Bobot | Yang dinilai |
|---|---|---|
| Harmoni rona | 40% | Rona warna berwarna dicocokkan ke pola monokromatik, analog, komplementer, split-komplementer, atau triadik. Warna netral (putih, krem, abu-abu, hitam) selalu aman. |
| Pengantin terlihat di panggung | 20% | Selisih warna (ΔE, CIELAB) gaun dan busana pria terhadap panggung; ideal ≥ 20. |
| Pengantin paling menonjol | 10% | Gaun harus beda dari seragam keluarga, bridesmaid, dan panitia; ideal ΔE ≥ 14. |
| Keseimbangan | 15% | Maksimal 2 warna mencolok, dan rentang terang-gelap minimal 30. |
| Tanpa warna bertabrakan | 15% | Warna yang hampir sama tapi tidak persis (ΔE 2–7, mis. ivory vs putih), atau pasangan komplementer yang sama-sama menyala. |

Skor total adalah rata-rata geometrik berbobot, jadi satu kriteria yang sangat buruk ikut menurunkan skor secara nyata.

Label skor: ≥85 sangat serasi, ≥70 serasi, ≥55 cukup serasi, ≥40 kurang serasi, di bawahnya bertabrakan.

Palet terakhir tersimpan otomatis di browser (localStorage).
