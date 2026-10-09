# Melodissimo — Plan Game-ification

> Prinsip: tiap fase harus bisa rilis/dicoba sendiri. Nggak ada fase yang "harus selesai semua dulu".

## Fase 1 — Melody Rush (mode endless)
Mode survival baru: note diberikan berurutan, makin lama makin cepet. Game over = 3 salah.

- **Aturan**: 1 note muncul → user tap tile yang benar → note berikutnya. Salah 3× habis.
  - Interval awal 2.5 detik, tiap 10 benar cepetin 8%, minimal 0.8 detik.
  - Skor: 10 poin/note, combo (benar beruntun) ×1…×5.
- **File baru**: `Views/Rush/MelodyRushView.swift`, `ViewModels/Rush/MelodyRushViewModel.swift` + route `.melodyRush` di `Route`.
- **Reuse**: `TilesComponentView`, `playSound(key:)`, `ProgressStore.recordCombo`.
- **Persist**: `UserDefaults` → `rushHighScore`.
- **Akses**: tombol di Dashboard (biar nggak ubah struktur unlock level).
- **Selesai jika**: bisa main sampai game over, high score tampil & ke-update.

## Fase 2 — Boss battle tiap 5 level
Quiz biasa + nyawa 3 hati + tempo naik + komposisi "boss".

- **Aturan**: 3 hati; salah = -1 hati. Kecepatan antar-soal naik tiap benar.
  - Boss visuals sederhana (sprite/emoji dulu, asset belakangan).
  - Kalah → boleh ulang; Menang → unlock level berikutnya + bonus bintang visual.
- **Reuse**: alur `NotationQuizView` — tinggal flag `isBoss` di `Route.notationQuiz` atau level % 5 == 0.
- **Selesai jika**: level 5 & 10 jadi boss, hati & tempo berfungsi.

## Fase 3 — Economy ringan (koin)
- Koin: +1/note benar (quiz & rush), bonus koin dari boss.
- Toko kecil: skin tile (warna, dulu) — 3–4 item.
- **Persist**: `coins`, `equippedTileSkin` di `ProgressStore`. TANPA class economy terpisah — cukup di ProgressStore biar nggak over-engineered.
- **Selesai jika**: koin terkumpul, skin bisa dibeli & kepake di semua mode.

## Fase 4 — Peta dunia + maskot
- Reskin `NotationQuizLevelMenuView` jadi world map: 3–4 zona bertema, tiap zona 10 level.
- Maskot kecil jalan sepanjang peta sesuai `highestUnlockedLevel`.
- Asset: mulai dari ilustrasi statis sederhana, animasi belakangan.
- **Selesai jika**: peta tampil, zona terkunci sesuai progres lama (migration: hitung zona dari level terbuka).

## Backlog (kalau semua di atas selesai & masih semangat)
- Practice mode bebas (tanpa skor, tile berikutnya menyala).
- Review/spaced repetition per level di dashboard.
- Boss punya dialog/serangan khusus, achievement baru untuk rush.
- (Jauh) Pitch detection via mikrofon — app jadi alat latihan pianika asli.

## Konvensyen teknis (jangan diubah)
- Satu `NavigationStack` via `AppRouter` — mode baru masuk sebagai `Route` baru.
- Penyimpanan tetap `UserDefaults` via `ProgressStore` (single source of truth). Migrasi file JSON hanya kalau data per-note dibutuhkan (backlog).
- Tiap fase = 1 PR/commit logis + dicek manual di simulator iPad sebelum lanjut.
