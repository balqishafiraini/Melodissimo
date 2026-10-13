# Reference melody sources

One section per song: files/URLs used, version chosen, conflicts and how they were resolved, octave changes.

**General.** Rhythm in the PNG sheets is drawn as columns of digits with '.' marks; where a dotted pair was ambiguous the choice that makes the bar add up to the meter was used. Drafts under `Melodissimo/Data/Charts/` were hand-made in an earlier session and are unverified. Web notation sources were images only (no text), downloaded to a temp folder just to be read, not stored in the repo. No lyrics are copied (R7).

Web pages used: https://satusgiga.blogspot.com/2017/01/kumpulan-lagu-wajib-nasional-indonesia.html, https://ikisuga.blogspot.com/2018/08/lagu-wajib-nasional-mars-harapan-bangsa.html, https://ikisuga.blogspot.com/2018/01/lagu-wajib-nasional-bhinneka-tunggal-ika.html, https://www.seputarmusikal.com/2017/12/bhinneka-tunggal-ika.html, https://www.detik.com/pop/music/d-8181637/lirik-lagu-bangun-pemudi-pemuda-lengkap-dengan-makna-dan-not-angka, https://www.detik.com/jateng/budaya/d-8201907/lirik-lagu-gugur-bunga-ciptaan-ismail-marzuki-beserta-not-dan-sejarahnya

## Indonesia Raya

- **Sources:** Notasi/indonesiaRaya.png (primary); app melody in LevelFeederModel (pitch order cross-check).
- **Choice / conflicts:** Verse only (stanza 1, rows 1–9), ending on the tonic; the chorus and the repeat/volta are left out (one-stanza rule). Rhythm of dotted pairs was resolved by bar-length sums (the sheet's '.' columns are ambiguous). **Open doubt:** rhythm of bars 1–2 of each line; B2 audio draft was useless (LCS 0.01).

## Bagimu Negeri

- **Sources:** Notasi/bagimuNegeri.png (zoomed 2×).
- **Choice / conflicts:** All 4 rows. **Octave change:** rows 1 sheet has low dots down to E3 (below the keyboard's F3), so the first phrase is written an octave up (same as row 3). The recording plays it lower, only pitch class matches there.

## Hari Merdeka

- **Sources:** Notasi/hariMerdeka.png.
- **Choice / conflicts:** 2/4 (beat = quarter). Rows 1–6 (verse + 'Merdeka' chorus); the 'Kita tetap setia' bridge (rows 7–11) is left out. Low/plain octave of rows 5–6 guessed from melodic contour.

## Garuda Pancasila

- **Sources:** Notasi/garudaPancasila.png; draft chart_garuda-pancasila.json (re-barred: the draft had dropped the pickup bar).
- **Choice / conflicts:** Whole song, one pass. Last two bars follow the draft.

## Maju Tak Gentar

- **Sources:** Notasi/majuTakGentar.png; draft chart_maju-tak-gentar.json.
- **Choice / conflicts:** Repeated line (draft row 3) and the doubled final line cut. First bar simplified to 5 5 [3 5] 1˙ (the draft's 4-slot hold groups were implausible). B2 audio draft agrees on pitch (LCS 0.61).

## Bangun Pemudi Pemuda

- **Sources:** Staff + angka score image from satusgiga/ikisuga blogspot (do=C, 4/4); staff notation used to read octaves and rhythm. detik.com cites the Kemenpora HSP-96 score (image only).
- **Choice / conflicts:** One pass, 12 bars. The angka line has a typo in bar 11 (3 instead of 2); the staff wins on pitch (D5). Only one image source, no second independent source found (web results only had images); the recording is the tie-breaker in B5.

## Bendera Merah Putih

- **Sources:** Notasi/merahPutih.png ('Merah Putih'); draft chart_merah-putih.json re-barred with a 1-beat pickup.
- **Choice / conflicts:** Verse 1 of the repeated melody. Same tune as track 7 is **unconfirmed** (B2 audio draft had 0 notes); B5's alignment score will show it.

## Mars Harapan Bangsa

- **Sources:** Staff + angka score (Do = Bb, 2/4 marcia) from satusgiga/ikisuga blogspot.
- **Choice / conflicts:** Whole melody, 32 bars. Digits copied as-is (do → C); octave read from the staff. B2 key guess for this recording was weak (A# minor 0.62), so identity is **unconfirmed** until B5.

## Indonesia Tetap Merdeka

- **Sources:** Notasi/indonesiaTetapMerdeka.png; draft chart_indonesia-tetap-merdeka.json re-barred with a pickup.
- **Choice / conflicts:** The sheet repeats rows 1/2 and rows 3-4/5-6; the repeats are cut (stanza = rows 1, 3, 4 + final tonic).

## Bhinneka Tunggal Ika

- **Sources:** Music Amateur score image (angka, 4/4, do=C) from seputarmusikal.com; staff version (do=F) from ikisuga blogspot for cross-check of pitch and rhythm.
- **Choice / conflicts:** Rows 1–3 plus the final line; the middle rows 4–7 are left out to keep the stage short, so there is a jump in the harmony before the last line. Two images, same pitches.

## Api Kemerdekaan

- **Sources:** Staff + angka score (Do = G) from satusgiga/ikisuga blogspot (two images).
- **Choice / conflicts:** Verse 1 only (16 bars); the modulating 'Air mataku' section is left out. Digits are relative so do=C copies them; `4#` = the raised 4 (C♯ in G). Triplet read from the staff.

## Halo Halo Bandung

- **Sources:** Notasi/haloHaloBandung.png; draft chart_halo-halo-bandung.json.
- **Choice / conflicts:** Whole song, one pass. Bar 3 of the last line (5 3 5 1 3 3 4) groups guessed as pairs.

## Tanah Airku

- **Sources:** Notasi/tanahAirku.png; draft chart_tanah-airku.json (re-barred with a 2-beat pickup).
- **Choice / conflicts:** First half of the verse only (draft). B2 audio draft agrees on pitch (LCS 0.88). Rhythm of bar 1 uncertain.

## Dari Sabang Sampai Merauke

- **Sources:** Notasi/dariSabangSampaiMerauke.png; draft chart_dari-sabang-sampai-merauke.json re-barred with a pickup.
- **Choice / conflicts:** Whole song, one pass. B2 key guess was weak (D# major 0.35).

## Mengheningkan Cipta

- **Sources:** Notasi/mengheningkanCipta.png (the draft chart was wrong, so this is hand-read).
- **Choice / conflicts:** Whole song, one pass (solemn). Bar groupings by sums.

## Gugur Bunga

- **Sources:** Angka score image (mastugino blogspot) via satusgiga blogspot; detik.com and tirto.id have the notation as images only.
- **Choice / conflicts:** Lines 1–2 (volta 2 ending), refrain left out. **Octave change:** the sheet starts on E3, so the song is raised one octave. The dot positions in the low-resolution image were hard to read; B2 audio draft agrees on pitch (LCS 0.54).
