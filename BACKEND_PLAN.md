# Melodissimo — Backend & Live-Ops Plan

> This document is written for an AI executor (Claude Sonnet) working **one task per session**, like `GAME_PLAN.md`.
> Read §1 (decisions), §3 (architecture), §4 (contracts) and §6 (executor rules) before touching code.
> Two repositories are involved: the **iOS app** (this repo) and a new **backend repo** (`melodissimo-backend`, §3.2).

---

## Progress tracker

| Phase | Theme | Where | Ships as |
|---|---|---|---|
| **E** | **Economy & shop as data** (remote-ready shop, Alpanica outfits, hearts/revive, coin packs). **Can start now, no backend needed** | iOS | **v3.x+1** |
| **I** | **International**: any language, per-country catalog, Do-Re-Mi / ABC / 123 note labels, world-song packs | both | v4.x |
| B0 | Decisions, accounts, domain **[USER]** | — | — |
| B1 | Contracts: JSON Schemas + content export from the iOS app | both | internal |
| B2 | Backend skeleton: Worker, D1, R2, KV, CI, environments | backend | internal |
| B3 | Bootstrap: force/soft update, maintenance, flags, tuning values | backend | internal |
| B4 | Content publishing CLI: validate, sign, upload, release, rollback | backend | internal |
| B5 | iOS: API client, bootstrap, **update gate**, flags, tuning | iOS | **v3.x+1** |
| B6 | iOS: remote content (songs, charts, backing, score sheets, shop) | iOS | v3.x+1 |
| B7 | Monetization: Melodissimo Plus subscription + one-time song packs (StoreKit 2, paywall) | both | **v4.0** |
| B8 | Player accounts + cross-platform progress + server-verified purchases | both | v4.x |
| B9 | First-party analytics (privacy-safe) | both | v4.x |
| B10 | Android readiness: client spec + contract codegen for Kotlin | backend | later |
| B11 | Stretch: admin web UI, remote campaign, live events | backend | later |

Task checkboxes are in §7. Tick them as tasks land.

**Order:** Phase E first (it makes the app data-driven, so the backend only has to swap where the data comes from). B0–B4 can run in parallel with E. B5+ come after. Phase I's contract rules (§4.10) apply **from B1.1 on**, so nothing has to be reshaped later; its app tasks come after B6.

---

## 1. Decisions (read first)

Each decision has a **recommendation**. Phase B0 asks the user to confirm them. Once confirmed, executors treat them as fixed.

| # | Decision | Recommendation | Why |
|---|---|---|---|
| D1 | Monetization model (`GAME_PLAN.md` §2.4 used to say **"No in-app purchases."**) | **Decided (2026-10-15):** everything shipped today stays free. Revenue comes from: **Melodissimo Plus**, an auto-renewing subscription (monthly + yearly) that unlocks every song pack, including future ones; **one-time song packs** ("Lagu Daerah Sumatra", "…Jawa", …); and **coin packs** (consumable IAP). Coins buy cosmetics (Alpanica outfits, skins) and **hearts** (nyawa) to continue a lost run. One currency only: real money → coins → items, never real money straight to hearts (§5.4). **No ads**, **no** loot boxes or random rewards for money. | Taking away free content gets bad reviews and App Review trouble. A subscription pays for a steady flow of new songs; one-time packs catch the parents who won't subscribe. No ads keeps the app clean, a clear difference from competitors that show full-screen ads. |
| D2 | App Store Kids Category? | **Decided (2026-10-15): No.** The app stays in **Music** (or Education) with age rating **4+**, like competitor *Pianika - Learn Melodica*, which sells subscriptions in Music at 4+. Kids Category rules don't apply. **No parental gate** anywhere (purchases, restore, links, sign-in). Apple's own purchase sheet and Ask to Buy already protect family accounts. | Kids Category limits monetization, analytics and SDK choice. A 4+ rating in Music gives the same audience with fewer limits. |
| D3 | Backend platform | **Cloudflare**: Workers (TypeScript + Hono) for the API, **R2** for assets (CDN, no egress fees), **D1** (SQLite) as source of truth, **KV** for the published config snapshot. | No SDK in the app (plain HTTPS + JSON, the same on Swift and Kotlin). Costs about $5/month at launch. Scales to millions of requests with no servers to run. One language (TS) for API + CLI. |
| D4 | Purchases | **StoreKit 2 on device** for v4.0 (B7). **Server-side verification + cross-platform entitlements** in B8 when accounts/Android arrive. Alternative: **RevenueCat** if Android launches within ~6 months of v4.0 (it saves building Play Billing verification). | StoreKit 2 transactions are already signed and verified on device; a server is not needed to sell on iOS alone. |
| D5 | Where content lives | Source of truth moves to `melodissimo-backend/content/` (Task B4.4). The iOS app ships a **bundled baseline pack** generated from it, so the app works offline on first launch. | One source for iOS and Android. Offline-first is required for kids (no network at school). |
| D6 | Domains | `api.<domain>` → Worker, `cdn.<domain>` → R2 public bucket. Staging: `api-staging.<domain>`, `cdn-staging.<domain>`. **[USER] picks the domain** (e.g. `melodissimo.app`). | Custom domains let us switch providers later without an app update. |
| D7 | Accounts | None until B8. Until then an **anonymous install id** (random UUID, no device identifiers) is used only for rollout bucketing. B8 adds optional **Sign in with Apple / Google**. | Kids' privacy (COPPA/GDPR-K): collect nothing until needed. |
| D8 | International | **Decided (2026-10-15): the app will go worldwide.** Indonesia stays the home market and the Nusantara Tour stays as it is (a cultural journey is a selling point abroad too). From day one every text the server sends is a **language map** (any language, not just `id`/`en`), and every song/pack/shop item/product can be **targeted by country** (§4.10). The app adds Do-Re-Mi / ABC note labels next to not angka, and world-song packs (public-domain folk and classical tunes) for other markets. | Building language maps and country targeting into the contracts now costs almost nothing; adding them after release means a schema bump and two code paths. |

---

## 2. What "anything can be updated" means here

The goal is that most changes ship **without an App Store release**. This table is the scope; every row maps to a task.

| Change | Mechanism | Needs app update? | Task |
|---|---|---|---|
| Force everyone off a broken/old build | `updatePolicy.minSupportedBuild` / `blockedBuilds` → blocking screen | No | B3, B5 |
| Nudge to update | `updatePolicy.recommendedBuild` → dismissible sheet | No | B3, B5 |
| Take servers/features down for maintenance | `maintenance` block | No | B3, B5 |
| Turn a feature on/off, gradual rollout, kill switch | `flags` with percent + rules | No (if the code path exists) | B3, B5 |
| Tune numbers (coin rewards, quiz length, daily bonus, approach time default) | `tuning` key/values with code defaults | No | B3, B5 |
| Fix a chart's timing, replace a backing track, fix a score sheet | New content release (same song id, new asset hash) | No | B4, B6 |
| Add a new song (any mode that already exists) | New content release | No | B4, B6 |
| Add/reprice a shop cosmetic that is colors only | Content release (`shop`) | No | E1, B6.4 |
| Add a new **Alpanica outfit** (new art) | Content release with `preview` + `overlay` PNGs (§5.5) | No | E2, B6.4 |
| Sale, limited-time or "new" item | `availableFrom/Until`, `tags`, price change in a content release | No | E1, B6.4 |
| Change coin pack amounts, revive price, hearts per revive | Product `grants` in the manifest + `tuning` keys | No | E4, E5 |
| New coin pack / hearts bundle for real money | Product in App Store Connect + `products` entry with `grants` | No (after E5 ships) | E5 |
| New shop **category** (e.g. stage backgrounds) | Code (a new `ShopCategory` and where it's drawn) + `minAppBuild` | **Yes** | — |
| Add a language for content (song titles, shop names, server messages) | Add the language key to the content's language maps | No | I1 |
| Show a pack/item only in some countries, or feature it first there | `markets` on the item / pack (§4.10) | No | I2 |
| Add a language to the app's own UI | `<lang>.lproj/Localizable.strings` | **Yes** | I4 |
| Sell a new song pack | Product in App Store Connect + content release with `access.productIds` (always including the Plus ids) | No (after B7 ships) | B7 |
| Give Plus subscribers new songs | Content release: add songs to a Plus-accessible pack | No | B7 |
| Announcements / event banners | `announcements` | No | B3 (+UI in B11) |
| New game mode, new stage type, new UI | Code | **Yes** — gate it with `minAppBuild` on content items + a flag | — |
| New content schema field the old app can't read | `schemaVersion` bump; old clients keep receiving the last compatible release | Yes for the new field, old apps keep working | B4 |

**Rule:** anything the server sends must have a safe fallback in the app. If the network, the server or a release is broken, the app runs on its cached or bundled data.

---

## 3. Architecture

### 3.1 Overview

```
                ┌─────────────────────────── melodissimo-backend (git) ───────────────────────────┐
                │ contracts/  JSON Schemas (source of truth for API + content shapes)             │
                │ content/    songs, charts, audio, score sheets, shop, products  (Git LFS audio)  │
                │ tools/mdm   CLI: validate · build · sign · publish · promote · rollback · policy │
                │ api/        Cloudflare Worker (Hono, TypeScript)                                 │
                └───────────────┬───────────────────────────────────────┬──────────────────────────┘
                                │ mdm publish (CI or laptop)             │ wrangler deploy (CI)
                                ▼                                        ▼
   ┌──────────── R2 bucket (cdn.<domain>) ────────────┐     ┌──────── Worker (api.<domain>) ────────┐
   │ assets/<sha256>.<ext>        immutable, cached ∞ │     │ GET  /v1/bootstrap   ← KV snapshot    │
   │ manifests/<contentVersion>.json + .sig           │     │ POST /v1/events      → Analytics Eng. │
   └──────────────────────────────────────────────────┘     │ /v1/players/* /v1/purchases/* (B8)    │
                                ▲                           │ /admin/*  (bearer token / CF Access)  │
                                │ download + verify sha/sig │        │ writes          │ reads      │
                                │                           │        ▼                 ▼            │
   ┌──────── iOS app (later Android) ──────────┐            │   D1 (truth) ──publish──► KV (live)    │
   │ BootstrapService → UpdateGate, Flags,     │──HTTPS────►└────────────────────────────────────────┘
   │   Tuning, Maintenance                     │
   │ ContentStore → SongLibrary, SongChart,    │
   │   BackingTrackPlayer, ScoreSheet, Shop    │
   │ Entitlements (StoreKit 2) → access checks │
   │ Bundled baseline pack (offline fallback)  │
   └───────────────────────────────────────────┘
```

**Hot path:** the app calls `GET /v1/bootstrap` once per launch and on return to foreground (at most every 15 min). The Worker reads one KV key (the live snapshot), evaluates rules for this client, and returns JSON. D1 is never on the hot path. Assets come straight from the CDN by content hash, so they cache forever.

### 3.2 Backend repo layout

New git repo at `/Users/macbook/Documents/Coding/melodissimo-backend` (sibling of the iOS repo). pnpm workspace.

```
melodissimo-backend/
  package.json  pnpm-workspace.yaml  tsconfig.base.json  .nvmrc (20)  .gitattributes (LFS: *.m4a *.png)
  README.md                       how to run, deploy, publish (kept current by every task)
  contracts/
    schema/
      bootstrap.schema.json       response of GET /v1/bootstrap
      manifest.schema.json        content pack manifest
      song.schema.json  chart.schema.json  shop.schema.json  product.schema.json
      events.schema.json          POST /v1/events body (B9)
    examples/                     one valid example per schema (used by tests on BOTH platforms)
    src/index.ts                  generated TS types (json-schema-to-typescript) + ajv validators
  api/
    wrangler.toml                 envs: dev, staging, production
    migrations/0001_init.sql …    D1 migrations (never edit an applied migration)
    src/
      index.ts                    Hono app, route mounting, error handler
      env.ts                      Env bindings type
      middleware/clientInfo.ts    parses X-App-* headers into ClientInfo
      middleware/adminAuth.ts
      routes/bootstrap.ts  routes/admin.ts  routes/events.ts  routes/health.ts
      domain/updatePolicy.ts      pure: (policy, client) → UpdateDirective
      domain/flags.ts             pure: (flags, client) → Record<string, boolean>
      domain/rollout.ts           pure: bucket(installId, salt) → 0…99 (FNV-1a)
      domain/releaseSelect.ts     pure: (releases, client) → release | null
      domain/snapshot.ts          D1 → LiveSnapshot (written to KV)
      db/*.ts                     typed queries
    test/*.test.ts                vitest + @cloudflare/vitest-pool-workers
  tools/mdm/
    src/cli.ts                    commander; subcommands below
    src/commands/content-*.ts  release-*.ts  policy-*.ts  flag-*.ts  maintenance-*.ts  keys-*.ts
    src/lib/build.ts              content/ → dist/pack (hashing, manifest)
    src/lib/sign.ts               Ed25519 sign/verify (@noble/ed25519)
    src/lib/validate.ts           schema + semantic rules (§4.6)
  content/
    songs/<slug>/song.json  songs/<slug>/chart.json  songs/<slug>/backing.m4a  songs/<slug>/sheet.png
    shop/items.json  shop/art/<itemId>.png
    packs.json  products.json
    retired.json                  ids that were removed (validator allows them to disappear)
  .github/workflows/ci.yml        lint, typecheck, test, content validate on every push
  .github/workflows/deploy.yml    deploy api to staging on main; production on tag `api-v*`
```

### 3.3 iOS client layout (new files)

All new logic lives under `Models/` or `Services/`. Rules from `GAME_PLAN.md` §3.1 still apply (iOS 16.6, no `@Observable`, `ObservableObject` singletons, `Models/` without SwiftUI/UIKit).

```
Melodissimo/
  Services/Backend/
    BackendEnvironment.swift      base URLs per build config, DEBUG override (-apiBase)
    APIClient.swift               URLSession wrapper, standard headers, timeouts, JSON decoding
    InstallID.swift               random UUID in UserDefaults `backend_installId`
    BootstrapService.swift        fetch + cache bootstrap, publishes state (ObservableObject)
    ContentStore.swift            active content pack: songs, shop, products, asset URLs
    AssetDownloader.swift         download by sha256, verify, store in Application Support
    Entitlements.swift            (B7) StoreKit 2 owned products, ObservableObject
  Services/Store/
    StoreService.swift            (E5) the only StoreKit wrapper: products, buy, restore, transaction updates
  Models/Backend/
    Bootstrap.swift               Codable types mirroring bootstrap.schema.json
    ContentManifest.swift         Codable types mirroring manifest.schema.json
    UpdateDirective.swift         pure: decides none / soft / hard from policy + build
    FeatureFlags.swift            typed flag accessors with code defaults
    Tuning.swift                  typed tuning values with code defaults
    ManifestVerifier.swift        Ed25519 (CryptoKit Curve25519.Signing) + sha256
    ContentAccess.swift           (B7) pure: (item access, owned products) → locked/unlocked
  Models/Shop/
    ShopItem.swift  ShopCatalog.swift (E1)   ArtSource.swift (E2)
    StoreProduct.swift  PurchaseGrants.swift (E5)
  Models/Game/Revive.swift        (E4) pure revive rules
  Data/Shop/shop.json  products.json   (E1, E5) bundled catalog, same shape as the manifest
  Views/Backend/
    ForceUpdateView.swift  SoftUpdateSheet.swift  MaintenanceView.swift
    PaywallView.swift (B7)  PlusPaywallView.swift (B7)  PackStoreView.swift (B7)
  Data/Content/baseline/          bundled pack: manifest.json, manifest.sig, assets/<sha>.<ext>
MelodissimoTests/
  Backend/ UpdateDirectiveTests, FeatureFlagsTests, TuningTests, ManifestVerifierTests,
           ContentStoreTests, BootstrapServiceTests (URLProtocol stub), ContentAccessTests
  Fixtures/ copies of contracts/examples/*.json
```

### 3.4 Invariants (never break)

1. **Ids are forever.** Song ids (slugs), shop item ids, pack ids, product ids, flag keys, tuning keys and persistence keys are never renamed or reused. A removed id goes into `content/retired.json`. The validator (§4.6) enforces this against the previous live release.
2. **Trophy keys use the canonical title.** Today the trophy bool is keyed by the exact song title (`GAME_PLAN.md` §3.4). For every song, `title.canonical` (Indonesian, never localized) is that key. Display titles come from `title.id` / `title.en`.
3. **Offline-first.** The app never waits on the network for more than **1.5 s** at launch. With no network it uses the last cached bootstrap, then built-in defaults; content falls back to the cached pack, then the bundled baseline.
4. **Never switch content mid-play.** A downloaded release is activated only when `PlaySession.isActive == false` and the router is at Home (or on next launch).
5. **Additive API.** `/v1` only gains optional fields. Clients ignore unknown fields and treat unknown enum values as "skip this item". A breaking change means `/v2` served alongside `/v1`.
6. **Price strings never come from our server.** Prices are shown from StoreKit / Play Billing only.
7. **No secrets in either repo.** Signing private key, admin token, App Store keys: `wrangler secret` / GitHub Actions secrets / the user's keychain only.
8. **Production is changed by the user.** Executors deploy to **staging** only. `mdm … --env production` and `wrangler deploy --env production` are run by the user (or by CI on a tag the user pushes).

---

## 4. Contracts

JSON Schemas in `contracts/schema/` are the source of truth. Below are the shapes with examples; Task B1.1 turns them into schemas.

### 4.1 Request headers (every app → API call)

| Header | Example | Notes |
|---|---|---|
| `X-App-Platform` | `ios` | `ios` \| `android` |
| `X-App-Version` | `3.4.0` | `CFBundleShortVersionString` |
| `X-App-Build` | `57` | `CFBundleVersion`, **integer**. All comparisons use the build number. |
| `X-Install-Id` | `6F1C…` | random UUID, §D7 |
| `X-Content-Version` | `12` | active content pack version, `0` = bundled baseline only |
| `X-Schema-Version` | `1` | highest content schema this binary understands |
| `Accept-Language` | `id-ID` | the player's languages, in order of preference |
| `X-Storefront` | `IDN` | App Store / Play country (ISO 3166-1 alpha-3 from `Storefront.current`), for country targeting and pricing tests. Empty if unknown. |

### 4.2 `GET /v1/bootstrap` → 200

```json
{
  "serverTime": "2026-10-15T08:00:00Z",
  "ttlSeconds": 900,
  "update": {
    "action": "none",                         // "none" | "soft" | "hard"
    "policy": { "minSupportedBuild": 40, "recommendedBuild": 57, "blockedBuilds": [52] },
    "storeUrl": "https://apps.apple.com/app/id0000000000",
    "title":   { "id": "Versi baru tersedia", "en": "A new version is available" },
    "message": { "id": "…", "en": "…" }
  },
  "maintenance": null,                        // or { "title": {…}, "message": {…}, "until": "ISO8601", "blocksPlay": false }
  "flags":  { "shop": true, "dailyChallenge": true, "micInput": false, "packStore": false },
  "tuning": { "coins.perNewStar": 10, "coins.dailyBase": 50, "quiz.questions": 8 },
  "content": {
    "version": 12,
    "schemaVersion": 1,
    "manifestUrl": "https://cdn.example.app/manifests/12.json",
    "signatureUrl": "https://cdn.example.app/manifests/12.json.sig",
    "sha256": "9f2c…"
  },
  "announcements": [
    { "id": "merdeka-2026", "startsAt": "…", "endsAt": "…", "kind": "banner",
      "title": {…}, "body": {…}, "imageUrl": null, "route": "freePlay" }
  ]
}
```

- `content` is `null` when no release is compatible with this client (then the app keeps what it has).
- `update.action` is computed by the server (§4.4) **and** recomputed by the app from the cached `update.policy`, so a hard block still works offline.

### 4.3 Content manifest (`manifests/<version>.json`)

```json
{
  "schemaVersion": 1,
  "contentVersion": 12,
  "createdAt": "2026-10-15T07:55:00Z",
  "minAppBuild": { "ios": 57, "android": 1 },
  "assets": {
    "chart.halo-halo-bandung": { "path": "assets/3b1f….json", "sha256": "3b1f…", "bytes": 4210, "kind": "chart",   "prefetch": true  },
    "bgm.halo-halo-bandung":   { "path": "assets/a77c….m4a",  "sha256": "a77c…", "bytes": 701234, "kind": "audio", "prefetch": false },
    "sheet.halo-halo-bandung": { "path": "assets/0d9e….png",  "sha256": "0d9e…", "bytes": 88120, "kind": "image",  "prefetch": true  }
  },
  "songs": [
    {
      "id": "halo-halo-bandung",
      "title": { "canonical": "Halo Halo Bandung", "id": "Halo Halo Bandung", "en": "Halo Halo Bandung" },
      "order": 90,
      "packId": "core",
      "isSolemn": false,
      "status": "live",                       // "live" | "hidden" | "comingSoon"
      "minAppBuild": 57,
      "chart": "chart.halo-halo-bandung",
      "backing": "bgm.halo-halo-bandung",     // optional
      "sheet": "sheet.halo-halo-bandung",     // optional; falls back to bundled asset name below
      "bundledSheetImage": "haloHaloBandung", // existing Notasi asset name, for the 16 shipped songs
      "region": null,                          // e.g. "sumatra" for Lagu Daerah
      "tags": ["nasional"]
    }
  ],
  "packs": [
    { "id": "core", "title": {…}, "access": { "type": "free" } },
    { "id": "daerah-sumatra", "title": {…}, "description": {…}, "art": "art.pack.daerah-sumatra",
      "access": { "type": "product", "productIds": ["melodissimo.pack.daerah_sumatra", "melodissimo.plus.monthly", "melodissimo.plus.yearly"] } }
  ],
  "shop": {
    "items": [
      { "id": "keyboard_batik", "category": "keyboard", "kind": "cosmetic",
        "name": { "id": "Merah Batik", "en": "Merah Batik" }, "price": { "coins": 100 },
        "colors": ["#7B241C", "#D35400"], "order": 20, "minAppBuild": 1, "status": "live" },
      { "id": "outfit_bow", "category": "outfit", "kind": "cosmetic",
        "name": { "id": "Pita", "en": "Bow" }, "price": { "coins": 100 },
        "bundledArt": { "preview": "alpanica_outfit_bow", "overlay": "alpanica_acc_bow" }, "order": 110, "status": "live" },
      { "id": "outfit_topi_batik", "category": "outfit", "kind": "cosmetic",
        "name": { "id": "Topi Batik", "en": "Batik Hat" }, "price": { "coins": 300 },
        "art": { "preview": "art.outfit_topi_batik.preview", "overlay": "art.outfit_topi_batik.overlay" },
        "tags": ["new"], "availableFrom": "2026-11-01T00:00:00Z", "availableUntil": null,
        "plusOnly": false, "order": 200, "minAppBuild": 60, "status": "live" },
      { "id": "boost_heart", "category": "boost", "kind": "consumable",
        "name": { "id": "Nyawa", "en": "Heart" }, "price": { "coins": 50 }, "maxStack": 99,
        "bundledArt": { "preview": "icon_heart" }, "order": 300, "status": "live" }
    ]
  },
  "products": [
    { "id": "melodissimo.pack.daerah_sumatra", "type": "nonConsumable", "unlocks": ["pack:daerah-sumatra"] },
    { "id": "melodissimo.plus.monthly", "type": "autoRenewable", "group": "plus", "unlocks": ["pack:*"] },
    { "id": "melodissimo.plus.yearly",  "type": "autoRenewable", "group": "plus", "unlocks": ["pack:*"] },
    { "id": "melodissimo.coins.small",  "type": "consumable", "grants": { "coins": 300 },  "order": 1 },
    { "id": "melodissimo.coins.medium", "type": "consumable", "grants": { "coins": 1100 }, "order": 2, "badge": "popular" },
    { "id": "melodissimo.coins.large",  "type": "consumable", "grants": { "coins": 3000 }, "order": 3, "badge": "bestValue" },
    { "id": "melodissimo.bundle.starter", "type": "consumable", "grants": { "coins": 500, "items": { "boost_heart": 5 } },
      "oncePerPlayer": true, "order": 0 }
  ]
}
```

- The chart asset is exactly today's `SongChart` JSON (`id, title, bpm, notes[{k,b,d}], beatsPerBar?, offset?, beatTimes?`). **Do not change its shape.**
- A remote song's melody (`Song.keyIds`) is `chart.notes.map(\.k)`. Not-angka labels come from `NoteCatalog` by key id.
- `manifest.json.sig` = the 64-byte Ed25519 signature over the exact manifest bytes, base64-encoded. The app holds a list of trusted public keys and accepts a signature from any of them (key rotation = ship the new key in the app first, sign with it later).
- Every `{ "id": …, "en": … }` object is a **LocalizedText** (§4.10): any language code may appear, `en` is required, and the app falls back along its language list → `en` → any.
- Songs, packs, shop items and products may carry `markets` (§4.10); without it they are worldwide.
- Shop `price` is in **coins**, never real money. Real money only appears in `products` (prices come from the store, §3.4 #6).
- `kind`: `cosmetic` (owned once, can be equipped) or `consumable` (a stack the player uses up, e.g. hearts). `category` decides where it is drawn; an unknown `category` or `kind` is skipped by old apps.
- Art: `bundledArt` names asset-catalog images already in the app; `art` names downloaded assets. Both may be set: downloaded art wins once it is on disk. An outfit needs `overlay` (drawn on every pose) and `preview` (shop card, certificate).
- `grants` is the only thing a consumable product does. Changing `grants` (e.g. a +20 % promo) is a content release, not an app update. Product ids name the size (`small/medium/large`), not the amount, so amounts can change.

### 4.4 Update policy rules (server `domain/updatePolicy.ts` and app `UpdateDirective.swift`: same logic, same test vectors)

```
input: build, policy { minSupportedBuild, recommendedBuild, blockedBuilds[] }
if build in blockedBuilds            → hard
if build < minSupportedBuild          → hard
if build < recommendedBuild           → soft
else                                  → none
```
- Soft prompts show at most once per `recommendedBuild` per 3 days (UserDefaults `backend_softUpdateShown_<build>` = date).
- Hard block screen: logo, localized message, "Update" button (opens `storeUrl`), no way past it. **Exception:** DEBUG builds can dismiss it.

### 4.5 Flags and rollout

D1 row: `key, enabled, rolloutPercent (0–100), rules JSON, description`.
`rules` is a list of conditions that must all match: `{ "platform": ["ios"] }`, `{ "minBuild": 57 }`, `{ "maxBuild": 80 }`, `{ "language": ["id"] }`, `{ "country": ["IDN", "MYS"] }`, `{ "notCountry": ["IDN"] }`. Tuning values can carry the same rules (e.g. a different revive coin price per country), so the `tuning` table gets a `rules_json` column and the most specific matching row wins.
Result for a client: `enabled && rulesMatch && bucket(installId, key) < rolloutPercent`.
`bucket = fnv1a32(installId + ":" + key) % 100` (salting by key makes rollouts independent). Same function in TS and Swift with shared test vectors in `contracts/examples/rollout-vectors.json`.

The app knows each flag's **code default** (`FeatureFlags.swift`). A flag missing from the response uses the default. Flags are **only for code that already exists**; they gate features, they don't add them.

### 4.6 Content validation rules (`mdm content validate`, run in CI)

1. Every file matches its schema.
2. Every chart passes the same rules as `SongChart.isValid` (port it to TS and keep both in sync; shared vectors in `contracts/examples/charts/`).
3. Every asset reference exists; every hash matches; audio is `.m4a` AAC, ≤ 3 MB; images are `.png`, ≤ 1 MB.
4. **Id stability:** compared with the previous live release, no song / shop item / pack / product id disappears unless it's in `retired.json`, and a song's `title.canonical` never changes.
5. Every pack has at least one song; every `access.productIds` entry exists in `products`.
6. Solemn songs (`Indonesia Raya`, `Mengheningkan Cipta`, `Gugur Bunga`) stay `isSolemn: true` and in pack `core` (free). National-anthem content is never sold.
7. `contentVersion` is strictly greater than the latest existing release.

### 4.7 D1 schema (migration `0001_init.sql`)

```sql
CREATE TABLE update_policies (
  platform TEXT PRIMARY KEY CHECK (platform IN ('ios','android')),
  min_supported_build INTEGER NOT NULL DEFAULT 0,
  recommended_build   INTEGER NOT NULL DEFAULT 0,
  blocked_builds      TEXT    NOT NULL DEFAULT '[]',   -- JSON int[]
  store_url           TEXT    NOT NULL,
  title_json          TEXT    NOT NULL DEFAULT '{}',
  message_json        TEXT    NOT NULL DEFAULT '{}',
  updated_at          TEXT    NOT NULL
);
CREATE TABLE maintenance (
  platform TEXT PRIMARY KEY, active INTEGER NOT NULL DEFAULT 0, blocks_play INTEGER NOT NULL DEFAULT 0,
  title_json TEXT NOT NULL DEFAULT '{}', message_json TEXT NOT NULL DEFAULT '{}', until TEXT, updated_at TEXT NOT NULL
);
CREATE TABLE flags (
  key TEXT PRIMARY KEY, description TEXT NOT NULL DEFAULT '',
  enabled INTEGER NOT NULL DEFAULT 0, rollout_percent INTEGER NOT NULL DEFAULT 100,
  rules_json TEXT NOT NULL DEFAULT '[]', updated_at TEXT NOT NULL
);
CREATE TABLE tuning (
  key TEXT PRIMARY KEY, value_json TEXT NOT NULL, description TEXT NOT NULL DEFAULT '', updated_at TEXT NOT NULL
);
CREATE TABLE releases (
  content_version INTEGER PRIMARY KEY, schema_version INTEGER NOT NULL,
  manifest_path TEXT NOT NULL, manifest_sha256 TEXT NOT NULL,
  min_build_ios INTEGER NOT NULL, min_build_android INTEGER NOT NULL,
  status TEXT NOT NULL CHECK (status IN ('uploaded','live','paused','rolled_back')),
  rollout_percent INTEGER NOT NULL DEFAULT 100,
  notes TEXT NOT NULL DEFAULT '', created_at TEXT NOT NULL, promoted_at TEXT
);
CREATE TABLE announcements (
  id TEXT PRIMARY KEY, starts_at TEXT NOT NULL, ends_at TEXT NOT NULL,
  platforms_json TEXT NOT NULL DEFAULT '["ios","android"]', min_build INTEGER NOT NULL DEFAULT 0,
  payload_json TEXT NOT NULL, updated_at TEXT NOT NULL
);
CREATE TABLE audit_log (
  id INTEGER PRIMARY KEY AUTOINCREMENT, at TEXT NOT NULL, actor TEXT NOT NULL, action TEXT NOT NULL, payload_json TEXT NOT NULL
);
```
B8 adds `players`, `player_devices`, `player_links`, `progress` and `entitlements` (§7, Phase B8).

**Release selection** for a client (`domain/releaseSelect.ts`): among releases with `status = 'live'`, `schema_version <= X-Schema-Version`, `min_build_<platform> <= X-App-Build` and `bucket(installId, "release:" + version) < rollout_percent`, pick the highest `content_version`. **Rollback** = set the bad release to `rolled_back`; clients get the previous live one on their next bootstrap, and the app accepts a **lower** version than its active one when the server says so.

### 4.8 Live snapshot (KV key `live:v1`)

Every admin write runs `publishSnapshot()`: read all tables → one JSON `{ policies, maintenance, flags, tuning, releases (live/paused only), announcements (not ended), publishedAt }` → `KV.put('live:v1', …)`. `/v1/bootstrap` reads only this key (with a 60 s in-isolate memo). If the KV read fails, it returns 503 and the app uses its cache.

### 4.9 Admin API (bearer `ADMIN_TOKEN`; every call writes `audit_log`)

| Method | Path | Body |
|---|---|---|
| PUT | `/admin/update-policy/:platform` | policy fields |
| PUT | `/admin/maintenance/:platform` | `{ active, blocksPlay, title, message, until }` |
| PUT | `/admin/flags/:key` | `{ enabled, rolloutPercent, rules, description }` |
| DELETE | `/admin/flags/:key` | |
| PUT | `/admin/tuning/:key` | `{ value, description }` |
| POST | `/admin/releases` | `{ contentVersion, schemaVersion, manifestPath, manifestSha256, minBuild, notes }` → status `uploaded` |
| POST | `/admin/releases/:v/promote` | `{ rolloutPercent }` → `live` |
| POST | `/admin/releases/:v/pause` · `/rollback` | |
| PUT | `/admin/announcements/:id` · DELETE | |
| GET | `/admin/state` | full D1 state, for `mdm status` |

---

### 4.10 Languages and markets (international from day one)

**LocalizedText.** JSON Schema `$defs/LocalizedText`: an object whose keys are BCP-47 language codes (`id`, `en`, `ms`, `ja`, `pt-BR`, …) and whose values are strings; `en` is required. The server returns the **whole map** (it doesn't pick a language), so the app can follow its own language setting. The app picks: each of `Locale.preferredLanguages` (exact, then language only) → `en` → the first value. Song titles keep `title.canonical` (never shown, used for persistence keys, §3.4 #2).

**Markets.** Optional on songs, packs, shop items, products and announcements:
```json
"markets": { "include": ["IDN", "MYS", "SGP"], "exclude": [], "featuredIn": ["IDN"] }
```
- No `markets`, or an empty `include` → worldwide.
- The app filters with its storefront country (`X-Storefront`); if the storefront is unknown it shows worldwide items plus items whose `include` has the device region.
- `featuredIn` only changes order (shown first, with a badge), never availability.
- **Never take away what a player has:** an owned pack or item stays usable in every country.
- The 16 Indonesian songs and the Nusantara Tour stay worldwide (`markets` absent). World-song packs (I5) are worldwide too, but featured outside Indonesia.

**Text the server shows** (update messages, maintenance, announcements) uses LocalizedText as well. `mdm` commands take `--text en="…" --text id="…" --text ms="…"` instead of one flag per language (B3.3 builds them this way).

**Validation (§4.6 adds):** every LocalizedText has `en`; language keys are valid BCP-47; `markets` country codes are valid alpha-3; a pack's songs are available in at least every market the pack is sold in.

## 5. Client behavior (iOS now; Android must match)

### 5.1 Launch sequence

```
App init (MelodissimoApp)
  ├─ ContentStore.shared.loadActive()      // sync, from disk: active pack or bundled baseline. Fast (<20 ms).
  ├─ BootstrapService.shared.loadCached()  // sync, last bootstrap JSON from disk → flags/tuning/policy usable now
  └─ BootstrapService.shared.refresh()     // async, 1.5 s timeout on first launch, 8 s otherwise
         ├─ update directive → CoordinatorView shows ForceUpdateView / SoftUpdateSheet
         ├─ maintenance       → MaintenanceView (blocks only server features; offline play continues
         │                      unless maintenance.blocksPlay == true)
         ├─ flags/tuning      → published; read by the next screen
         └─ content           → ContentStore.stage(release) in background → activate when safe (§3.4 #4)
On willEnterForeground: refresh() if older than ttlSeconds.
```

### 5.2 ContentStore resolution order

For every asset (chart, backing, sheet, art): **active downloaded pack** (file exists and its sha was verified at download) → **bundled baseline** → **legacy bundle resource** (`chart_<slug>.json`, `bgm_<slug>.m4a`, `Notasi` image) → built-in default (`SongChart.defaultChart`). The 16 shipped songs therefore keep working exactly as today even if every download fails.

Storage: `Application Support/Content/assets/<sha256>.<ext>` (excluded from iCloud backup), `Application Support/Content/manifests/<version>.json`, pointer `Application Support/Content/active.json` = `{ "version": 12 }`. Garbage-collect assets not referenced by the active or previous manifest once per launch, off the main thread.

Downloads: manifest + `prefetch: true` assets before activating; `prefetch: false` (audio) when the song's Stage Setup opens, with a progress ring; also prefetch on Wi-Fi when idle. Retry with backoff (1 s, 4 s, 16 s). If the signature or any sha256 doesn't match, discard the release and log `content_verify_failed`.

### 5.3 Access (B7)

`ContentAccess.isUnlocked(pack, ownedProducts)`: `free` → true; `product` → any of `productIds` owned, where an owned subscription means an **active** one (not expired, not revoked; billing grace period counts as active). When Plus lapses, Plus-only packs lock again; one-time packs stay unlocked forever. Progress, stars and coins earned in locked songs are never deleted. Locked songs show in Free Play with a lock and open the pack's paywall. The 16 current songs are in `core` (free) forever.

---

### 5.4 Economy rules (Phase E)

**Wallet.** Three totals that only ever increase, each merged with `max` by `CloudMerge` (the existing pattern from `GAME_PLAN.md` §2.4):
`coins_earnedTotal` (gameplay), `coins_purchasedTotal` (IAP grants, **new**), `coins_spentTotal`.
`balance = earned + purchased − spent`. Never store the balance itself.

**Inventory (consumables).** Per item: `inv_gained_<itemId>` and `inv_used_<itemId>`, both only increase, both `max`-merged. `count = gained − used`, clamped to `0…maxStack`.

**IAP grants are idempotent.** A purchased consumable is granted once per StoreKit transaction id: `iap_granted` (`[String]`, merged as `union`). Order: verify the transaction → if its id isn't in `iap_granted`, add the `grants` (coins to `coins_purchasedTotal`, items to `inv_gained_*`) and append the id **in the same UserDefaults write pass** → then `transaction.finish()`. If the app dies before `finish()`, StoreKit redelivers it and the ledger stops a double grant. `oncePerPlayer` products are hidden once any of their transaction ids is in the ledger.

**Hearts and revive ("Lanjut?").** Battle, Echo, Quiz and Melody Rush start with 3 hearts (`BattleConfig/EchoConfig/QuizConfig.hearts`, unchanged). When hearts reach 0 the run pauses on a **Continue** sheet:
- *Use 1 heart* (if the inventory count > 0), or *Pay N coins* (`tuning revive.coinCost`, default 50), or *Give up*.
- A revive restores `tuning revive.heartsRestored` (default 1) hearts. At most `tuning revive.maxPerRun` (default 2) revives per run.
- Plus members get `tuning plus.freeRevivesPerRun` (default 1) free revives first (a Plus perk that costs nothing to make).
- Not offered in the Daily Challenge (flag `reviveInDaily`, default off).
- **Stars stay honest:** a won run that used a revive gets at most `tuning revive.starCap` (default 1) star. Melody Rush scores from revived runs count for the local high score but are **not** sent to Game Center leaderboards.
- Every revive is logged to analytics (B9) as `revive_used {source: heart|coins|plus, mode}`.

**Price sanity (defaults, all tunable).** The whole cosmetic shop costs about 2,000 coins today, which a full campaign pays out. Coin packs are a shortcut, not a requirement: everything cosmetic stays earnable by playing. Suggested store prices (the user sets them in App Store Connect): small Rp 15.000, medium Rp 49.000, large Rp 119.000, starter bundle Rp 15.000.

### 5.5 Remote outfit art spec

`AlpanicaView` draws the pose and lays the outfit overlay on a clear canvas **the same size as the pose art** (`CharacterMotion.swift`, `AlpanicaOutfit.overlayName`). So a new outfit is two transparent PNGs:
- `overlay`: the outfit alone, exactly the pose canvas (same viewBox as `Design/svg/alpanica_*.svg`), exported at **3× the largest on-screen height** the app uses for Alpanica (check the `height:` call sites; about 1200 px tall), ≤ 300 KB.
- `preview`: Alpanica wearing it, same canvas, ≤ 300 KB.
Add `--png` export to `Design/generate_assets.py` so new outfits drawn as SVG in `Design/svg/` produce both files. The overlay must fit every pose and the walk/run frames: check it with `Design/gallery.html` before publishing.

## 6. Executor rules (for Sonnet)

1. **One task per session.** Read §1, §3, §4 and the task in full. Read every file listed under **Touches** before editing.
2. **iOS repo rules:** everything in `GAME_PLAN.md` §3.1 and §4 still applies (iOS 16.6, forbidden APIs, an Indonesian line in `id.lproj/Localizable.strings` for every new string, `Models/` free of SwiftUI/UIKit, tests for logic, the build + test commands, stage only touched paths). The project uses folders, so creating a file on disk is enough; confirm with a build.
3. **Backend repo rules:** TypeScript `strict`, ESM, Node 20, pnpm. No `any` in `domain/`. `domain/` is pure (no Env, no fetch) and fully unit-tested. Every route validates input with the ajv validators from `contracts`. Prettier + ESLint (config from Task B2.1).
4. **Verify before finishing (backend):**
   ```bash
   pnpm -r lint && pnpm -r typecheck && pnpm -r test
   ```
   Tasks that touch content also run `pnpm mdm content validate`.
5. **Shared logic stays identical.** `updatePolicy`, the rollout bucket, chart validity and (B8) progress merge exist in both TS and Swift. When you change one, change both and the shared vectors in `contracts/examples/`.
6. **Contracts first.** A change to an API or content shape starts with the JSON Schema + example, then TS types (`pnpm --filter contracts gen`), then the Swift `Codable` types by hand to match (B10 adds codegen).
7. **Deploy only to staging.** `wrangler deploy --env staging`, `mdm … --env staging`. List the production commands for the user at the end of the task.
8. **Secrets:** never print or commit secrets, or put them in test fixtures. Use `.dev.vars` (git-ignored) locally.
9. **Finish:** tick the task's checkbox in this file (in the iOS repo), then commit in each repo you touched with `Task B<x>.<y>: <title>`, staging only the paths you touched. Never `git add -A`.
10. **When the plan conflicts with the code,** make the smallest reasonable choice and record it in **§9 Executor notes**.
11. Tasks marked **⚠︎**: write a short plan first and wait for the user's OK. Tasks marked **[USER]**: list the steps for the user; don't attempt account sign-ups, payments or console actions yourself.

**Session prompt for the user to paste:**
```
Read BACKEND_PLAN.md: sections 1, 3, 4 and 6 fully, then Task B<X.Y>.
Execute Task B<X.Y> only, following the Executor rules.
For tasks marked ⚠︎, write a short plan first and wait for my OK before coding.
Finish with: lint/typecheck/tests (and iOS build + tests if the iOS app was touched) passing,
checkbox ticked, commit, and a list of things I should check by hand.
```

---

## 7. Phases & tasks

### Phase E — Economy & shop as data (iOS, can start now)

Goal: everything the shop sells is described by data with the **same shape as the manifest's `shop` and `products`** (§4.3). Until the backend exists, the data is a bundled JSON file; in B6.4 the source switches to ContentStore without touching the shop code again.

#### Task E1 — ⚠︎ Shop catalog as data
- [x] done
- **Touches:** `Models/Shop/ShopCatalog.swift`, `Models/Shop/ShopItem.swift` (new, split out), `Data/Shop/shop.json` (new), `Models/Progress/ProgressStore+Shop.swift`, `Views/Shop/ShopView.swift`, `Views/Shop/Skins.swift`, tests.
- Write `Data/Shop/shop.json` with today's 19 items in the §4.3 shape (ids, prices and colors **identical**; `name.id`/`name.en` = today's name, except "Default", which gets "Bawaan"/"Default").
- `ShopItem` gains `kind`, `name: LocalizedText`, `order`, `tags`, `availableFrom/Until`, `plusOnly`, `maxStack`, `art`/`bundledArt`, `minAppBuild`, `status`. `price` stays an `Int` of coins in Swift (decoded from `price.coins`). `ShopCategory` gains `boost`, and unknown values decode to `nil` (item skipped).
- `ShopCatalog` becomes a provider: `ShopCatalog.items` reads from a `ShopCatalogSource` protocol; the default source decodes `Data/Shop/shop.json` once (main-thread cache, like `SongChart`). Keep the old static array **only in tests**, as the expected list.
- Filters: `status == live`, `minAppBuild <= build`, inside the availability window. An owned item stays visible and equipped after its window ends.
- **Tests:** decoded ids/prices/colors equal the old list; unknown category skipped; window filter; owned-but-retired item still equipped; `purchasedShopItemCount` unchanged.

#### Task E2 — ⚠︎ Alpanica outfits as data
- [x] done
- **Touches:** `Views/Common/CharacterMotion.swift` (`AlpanicaOutfit`, `AlpanicaView`), `Views/Shop/Skins.swift`, `Views/Shop/ShopView.swift`, `Views/Campaign/CertificateView.swift` and every `AlpanicaView(outfit:)` call site (`grep -rn "outfit:"`), `Models/Shop/ArtSource.swift` (new), `Views/Common/ArtImage.swift` (new), `Design/generate_assets.py`, tests.
- `ArtSource` (Models, no SwiftUI): `.asset(String)` or `.file(URL)`. `ArtImage` view: asset → `Image(name)`, file → `UIImage(contentsOfFile:)` with an in-memory cache, falling back to the 🦙 emoji like `AssetImage`.
- Replace the closed `enum AlpanicaOutfit` with `struct AlpanicaOutfit: Hashable { let id: String; let preview: ArtSource; let overlay: ArtSource? }` plus `static let none`, built from the equipped outfit `ShopItem` (`bundledArt` today, downloaded `art` after B6.4). `equip_outfit` keeps storing the item id, so **no migration**.
- `Design/generate_assets.py --png` per §5.5.
- **Tests:** every bundled outfit item resolves to the same asset names as before (`alpanica_outfit_<variant>`, `alpanica_acc_<variant>`); an item with `.file` art resolves to the file; an unknown id → `.none`.
- **Manual QA:** Shop, Home, map, certificate and the walk/run frames with 3 different outfits look exactly as before.

#### Task E3 — Wallet v2 + inventory
- [x] done
- **Touches:** `Models/Progress/ProgressStore+Game.swift` (coins), `Models/Progress/ProgressStore+Shop.swift`, `Models/Progress/CloudMerge.swift`, `Views/Settings/SettingsView.swift` (reset progress), tests.
- Add `coins_purchasedTotal` and the balance formula from §5.4. Add `inventoryCount(_:)`, `addToInventory(_:count:)`, `useFromInventory(_:) -> Bool`, `buyConsumable(_ item:, count:) -> Bool` (pays coins, adds to the inventory, respects `maxStack`).
- `CloudMerge`: `coins_purchasedTotal` → max; prefixes `inv_gained_` and `inv_used_` → max; `iap_granted` → union.
- "Reset progress" must **not** remove `coins_purchasedTotal`, `inv_*` or `iap_granted` (paid things survive a reset). Earned coins reset as today. Say so in the Settings confirmation text.
- **Tests:** balance formula; two devices that each bought and used hearts converge to the right count after merging; reset keeps purchases.

#### Task E4 — ⚠︎ Hearts: revive / "Lanjut?"
- [x] done
- **Touches:** `ViewModels/Battle/BattleViewModel.swift` (also used by Melody Rush), `ViewModels/Echo/EchoViewModel.swift`, `ViewModels/Quiz/QuizViewModel.swift`, `Models/Game/Revive.swift` (new, pure), `Views/Common/ContinueSheet.swift` (new), the matching views, `Services/ResultRecorder.swift`, `Services/GameCenter.swift`, `id.lproj/Localizable.strings`, tests. If B5.2 (`Tuning`) hasn't landed yet, keep the defaults in `Revive.swift` and wire `Tuning` in later.
- The view models get a new phase `awaitingContinue` between "hearts hit 0" and `lost`, plus `revive(source:)` and `giveUp()`. The game clock is paused while the sheet is up (`PausableClock`).
- `Revive` (pure): decides the options offered (free Plus revive, heart from the inventory, coin price, none) from the config, run state, inventory, balance, Plus status and tuning, and applies the star cap per §5.4.
- `ContinueSheet`: a big heart, "Lanjut?", the offered options, and a 10-second timeout that counts as giving up. If the player can't afford the coins, the coin button opens the shop's Koin section and returns to the sheet.
- `ResultRecorder`: `PlayResult` gains `revivesUsed`; stars are capped; Rush runs with revives skip Game Center submission.
- **Tests:** options matrix; max per run; star cap; no revive in Daily; the coin spend or inventory use happens exactly once per revive.
- **Manual QA:** lose in Battle, Echo, Quiz and Rush → sheet → continue with a heart, with coins, give up; music and clock resume in sync.

#### Task E5 — ⚠︎ StoreKit foundation + coin packs
- [x] done
- **Touches:** `Services/Store/StoreService.swift` (new), `Models/Shop/StoreProduct.swift` (new), `Models/Shop/PurchaseGrants.swift` (new, pure), `Data/Shop/products.json` (new), `Melodissimo/Store/Products.storekit` (new), the Debug scheme's StoreKit configuration, `MelodissimoApp.swift`, tests.
- `products.json` in the §4.3 `products` shape (coin packs + starter bundle for now; Plus and packs are added in B7).
- `StoreService` (`ObservableObject` singleton, the **only** place that imports StoreKit): loads `Product`s for the ids in `products.json`; `buy(productId) async -> PurchaseOutcome` (`success / pending / cancelled / failed`); listens to `Transaction.updates` from launch; handles unfinished transactions at launch; hands verified consumables to `PurchaseGrants`. B7.2 extends this same service for Plus and packs.
- `PurchaseGrants.apply(transactionId:product:store:)` per §5.4 (ledger, then grant, then finish).
- **Tests:** a grant is applied once even when delivered twice; `oncePerPlayer` is hidden after purchase; an unknown product id is ignored; grants for an item not in the catalog stay in the inventory (it may come back).
- **Manual QA (StoreKit config):** buy each pack; kill the app before finish → relaunch grants exactly once; Ask to Buy pending, then approved; a failed purchase gives nothing.

#### Task E6 — ⚠︎ Shop UI: sections, coins, hearts
- [x] done
- **Touches:** `Views/Shop/ShopView.swift` (+ small subviews), `Views/Common/CoinBadge.swift`, `id.lproj/Localizable.strings`.
- Sections come from the data, not hard-coded: Keyboard, Notes, Alpanica, **Nyawa** (consumables with the owned count and ×1 / ×5 buttons), **Koin** (coin packs from `StoreService`, price from `Product.displayPrice`, `badge`, the starter bundle on top while available). Ordered by `order`. Badges for `tags` (`new`, `sale`) and a countdown for `availableUntil`. `plusOnly` items show a Plus badge and open the Plus paywall once B7.3 exists (hidden until then).
- Tapping the coin badge anywhere opens the shop at **Koin**. The `shop` flag (B5.5) hides the whole shop; a new flag `coinStore` hides only the Koin section (kill switch).
- **Manual QA:** iPad + iPhone layouts (`Sizing` rules), Indonesian strings, buying a heart and a coin pack, owned counts update.

#### Task E7 — [USER] Coin products in App Store Connect
- [ ] done
- Create the consumables `melodissimo.coins.small`, `.medium`, `.large` and `melodissimo.bundle.starter` with ID/EN names and review screenshots of the Koin section, and set the prices (suggestions in §5.4). The ids must match `products.json`.

### Phase B0 — Decisions & accounts

#### Task B0.1 — [USER] Confirm decisions and set up accounts (~1 h)
- [ ] done
1. Confirm or change D1–D7 in §1. Write the answers into §9.
2. Change the first line of `GAME_PLAN.md` §2.4 to "No ads. Revenue: Melodissimo Plus (subscription), one-time song packs, and coin packs; hearts are bought with coins (see `BACKEND_PLAN.md` D1, §5.4)."
3. Buy/choose the domain (D6). Add it to Cloudflare (the free plan is fine).
4. Cloudflare: enable **Workers Paid** ($5/mo) and create R2 (needs a payment method). Create an API token for CI with Workers Scripts:Edit, D1:Edit, Workers KV:Edit, R2:Edit.
5. Apple: in App Store Connect sign the **Paid Apps Agreement** and fill in tax/banking (needed for B7). Note the App Store id (for `storeUrl`).
6. Install locally: Node 20, pnpm (`corepack enable`), `git lfs install`.

### Phase B1 — Contracts

#### Task B1.1 — Create backend repo + contracts package
- [x] done
- **Touches (new repo):** root files, `contracts/**`.
- Create the repo at `/Users/macbook/Documents/Coding/melodissimo-backend` with the §3.2 skeleton (empty `api/`, `tools/mdm/`, `content/` folders with `.gitkeep`), `README.md`, `.gitignore` (node_modules, dist, .wrangler, .dev.vars, .mdmrc), `.gitattributes` for LFS.
- Write the `bootstrap`, `manifest`, `song`, `chart`, `shop` and `product` schemas (JSON Schema draft 2020-12) from §4.2–4.3. `additionalProperties: true` in responses (additive API), `false` in admin request bodies.
- `contracts/examples/`: one valid example per schema, plus `rollout-vectors.json` (20 `{installId, key, bucket}` rows) and `update-policy-vectors.json` (≥ 12 rows covering blocked, below min, between, equal, above).
- `contracts/src`: generated TS types and exported ajv validators. Script `pnpm --filter contracts gen`.
- **Tests:** every example validates; mutated examples (missing required field, wrong enum) fail.
- **Done when:** `pnpm -r test` is green and the README explains the contracts-first rule.

#### Task B1.2 — Export today's content from the iOS app
- [x] done
- **Touches (iOS):** `MelodissimoTests/Backend/ContentExportTests.swift` (new). **(backend):** `content/**`, `tools/mdm/src/commands/content-import-ios.ts`.
- iOS: a test that only runs when env `MELODISSIMO_EXPORT_DIR` is set (otherwise `XCTSkip`). For every `SongLibrary.all` song it writes `songs/<slug>/song.json` (`id`, `title.canonical` = current title, `title.id` / `title.en` = current title, `order` = index × 10, `packId: "core"`, `isSolemn`, `bundledSheetImage` = `notationImage`). (The shop needs no export: after E1/E5, `Data/Shop/shop.json` and `products.json` are copied as they are.)
  Run it with `TEST_RUNNER_MELODISSIMO_EXPORT_DIR=/tmp/melodissimo-export xcodebuild test … -only-testing:MelodissimoTests/ContentExportTests`.
- Backend: `mdm content import-ios --ios-repo ../Melodissimo --export /tmp/melodissimo-export` copies the export plus `Data/Charts/chart_<slug>.json` → `songs/<slug>/chart.json`, `Data/Sound/Backing/bgm_<slug>.m4a` → `backing.m4a`, and the `Assets.xcassets/Notasi/<name>.imageset` PNG → `sheet.png` (pick the largest scale).
- Add `content/packs.json` with the single `core` pack, copy `Data/Shop/shop.json` → `content/shop/shop.json` and `Data/Shop/products.json` → `content/products.json`, and add an empty `retired.json`.
- **Done when:** `content/` holds 16 songs with chart + backing + sheet and the shop + products files, and the schemas validate.

### Phase B2 — Backend skeleton

#### Task B2.1 — Worker + tooling + CI
- [x] done
- **Touches:** `api/**`, root lint/prettier config, `.github/workflows/ci.yml`.
- Hono app with `GET /health` → `{ ok: true, env, commit }`. `wrangler.toml` with `[env.staging]` and `[env.production]`, bindings `DB` (D1), `LIVE` (KV), `CDN` (R2), var `ENV_NAME`, secret `ADMIN_TOKEN`.
- Middleware: `clientInfo` (parses §4.1 headers; a missing build counts as 0), request id, JSON error handler (`{ error: { code, message } }`, no stack traces outside dev). No CORS.
- Vitest with `@cloudflare/vitest-pool-workers`; test `/health` and the error handler.
- CI: install, lint, typecheck, test on push/PR.
- **Done when:** `pnpm --filter api dev` serves `/health` locally and CI is green.

#### Task B2.2 — [USER + executor] Provision staging & production
- [ ] done
- The executor writes `api/scripts/provision.md` with the exact commands: `wrangler d1 create melodissimo-<env>`, `wrangler kv namespace create LIVE --env <env>`, `wrangler r2 bucket create melodissimo-cdn-<env>`, custom domains, `wrangler secret put ADMIN_TOKEN --env <env>`, and where to fill the ids into `wrangler.toml`.
- The user runs them for **staging** and **production**, enables the R2 public custom domains (`cdn-staging.<domain>`, `cdn.<domain>`) and sets cache rules: `assets/*` and `manifests/*` → `Cache-Control: public, max-age=31536000, immutable`.
- `deploy.yml`: staging on push to `main`; production on tag `api-v*`. Migrations run before deploy (`wrangler d1 migrations apply`).
- **Done when:** `https://api-staging.<domain>/health` returns ok.

### Phase B3 — Bootstrap & live config

#### Task B3.1 — D1 schema + pure domain logic
- [x] done
- **Touches:** `api/migrations/0001_init.sql`, `0002_seed.sql`, `api/src/domain/*.ts`, tests.
- Migration from §4.7. Seed: `update_policies` rows for ios/android with min 0 and recommended 0; flags `shop`, `dailyChallenge`, `micInput`, `coinStore` (on, matching today), `reviveInDaily` (off) and `packStore` (off); tuning keys mirroring `Models/Game/CoinRewards.swift`: `coins.perNewStar` 10, `coins.firstClear` 20, `coins.firstBossClear` 100, `coins.replayClear` 5, `coins.firstPractice` 15, `coins.rushAnswersPerCoin` 5, `coins.perEchoRound` 2, `coins.perQuizAnswer` 1, `coins.dailyBase` 50, `coins.dailyPerStreakDay` 10, `coins.dailyStreakCap` 5; and the revive keys from §5.4: `revive.coinCost` 50, `revive.heartsRestored` 1, `revive.maxPerRun` 2, `revive.starCap` 1, `plus.freeRevivesPerRun` 1.
- `rollout.ts`, `updatePolicy.ts`, `flags.ts`, `releaseSelect.ts` and `snapshot.ts` per §4.4–4.8, each 100 % covered, using the shared vectors.
- **Done when:** tests are green and the vectors pass.

#### Task B3.2 — `GET /v1/bootstrap` + admin config routes
- [x] done
- **Touches:** `api/src/routes/bootstrap.ts`, `routes/admin.ts`, `middleware/adminAuth.ts`, tests.
- Bootstrap per §4.2 from the KV snapshot. Return both `id` and `en` strings (the app may switch language).
- `Cache-Control: private, max-age=60`. Tests validate the response against `bootstrap.schema.json`.
- Admin routes per §4.9 (policy, maintenance, flags, tuning, announcements, state). Constant-time token compare. Every write: D1 batch → `audit_log` → `publishSnapshot()`.
- **Tests:** hard/soft/none by build, blocked build, maintenance per platform, flag rollout determinism, tuning passthrough, unauthorized admin = 401, snapshot republished after each write.
- **Done when:** deployed to staging, and `curl` with `X-App-Build: 1` after setting `min_supported_build: 2` returns `"action":"hard"`.

#### Task B3.3 — `mdm` config commands
- [x] done
- **Touches:** `tools/mdm/**`, README.
- `mdm --env <staging|production>` reads `MDM_API_URL_<ENV>` and `MDM_ADMIN_TOKEN_<ENV>` from the environment or `.mdmrc` (git-ignored). Production commands ask the user to type the environment name to confirm.
- Commands: `status`; `policy set <platform> [--min] [--recommended] [--block <build>] [--unblock <build>] [--store-url] [--text <lang>="…"]…` (any number of languages, `en` required); `maintenance on|off <platform> --text en="…" --text id="…"`; `flag set <key> [--on|--off] [--percent] [--rule platform=ios] [--rule minBuild=57]`; `flag rm`; `tuning set <key> <jsonValue>`; `announce …`.
- **Done when:** each command works against local `wrangler dev`, and the README has a cookbook (see §8).

### Phase B4 — Content publishing

#### Task B4.1 — Signing keys
- [x] done
- `mdm keys generate --out ~/.melodissimo/keys/<keyId>` writes an Ed25519 keypair (private key file mode 600) and prints the public key in base64 for the app.
- **[USER]** generates `k1`, stores a backup in their password manager, puts the private key into the GitHub secret `CONTENT_SIGNING_KEY`, and keeps it out of the repo.
- **Done when:** a sign/verify round-trip test passes with a throwaway key generated inside the test.

#### Task B4.2 — `mdm content validate` + `build`
- [x] done
- `validate` implements every rule in §4.6 (including the port of `SongChart.isValid`, tested with the shared chart vectors). For id stability it downloads the current live manifest of the chosen env; in CI on PRs use `--no-remote`, which compares with `content/.last-release.json` instead.
- `build --version <n>` → `dist/pack/manifest.json`, `manifest.json.sig`, `assets/<sha256>.<ext>`. Deterministic: the same input gives a byte-identical manifest (sorted keys, songs ordered by `order` then `id`).
- **Done when:** building twice gives identical hashes, and a broken chart, a renamed id and a missing asset each fail with a clear message.

#### Task B4.3 — `mdm content publish`, `release promote|pause|rollback`
- [x] done
- `publish --env staging [--version n]`: validate → build → upload assets to R2 (skip keys that already exist, via `HEAD`) → upload manifest + sig → `POST /admin/releases` (status `uploaded`). R2 access through its S3-compatible API with `@aws-sdk/client-s3`; credentials from env.
- `release promote <v> --percent 10|50|100`, `pause <v>`, `rollback <v>`, `release list`.
- After a successful promote to 100 %, write `content/.last-release.json` (version + id lists) and remind the user to commit it.
- **Done when:** publish + promote on staging, `GET /v1/bootstrap` returns the release, and rollback brings the previous one back.

#### Task B4.4 — Baseline export into the iOS app (content source of truth flips here)
- [x] done
- `mdm content export-baseline --ios-repo ../Melodissimo` builds the pack with the `contentVersion` of the latest live release (or 0) and writes it to `Melodissimo/Data/Content/baseline/` (manifest, sig, assets).
- Document in both READMEs: **from now on, new songs and chart fixes are made in `melodissimo-backend/content/`.** The backsound pipeline (`Scripts/backsound/`, see `BACKSOUND_PLAN.md`) keeps writing into the iOS repo for now; after a run, `mdm content import-ios --songs <slug,…>` pulls the result into `content/`.
- The legacy files `Data/Charts/*` and `Data/Sound/Backing/*` stay until Task B6.5 removes the duplicates.
- **Done when:** the baseline folder exists in the iOS repo (the app doesn't read it yet).

### Phase B5 — iOS: bootstrap, update gate, flags, tuning

#### Task B5.1 — Backend environment + API client
- [x] done
- **Touches:** `Services/Backend/BackendEnvironment.swift`, `APIClient.swift`, `InstallID.swift`, `Data/Info.plist`, project build settings, tests.
- Info.plist keys `MelodissimoAPIBaseURL` and `MelodissimoCDNBaseURL` come from the build setting `$(MELODISSIMO_API_BASE)` / `$(MELODISSIMO_CDN_BASE)`: Debug → staging, Release → production. The DEBUG launch argument `-apiBase <url>` overrides it (like `-qaOnlineServices`).
- The backend is separate from `OnlineServices` (Game Center/iCloud). Add its own switch: Info.plist `MelodissimoBackendEnabled` (Bool, default YES) and DEBUG argument `-qaBackend NO`, so the QA scripts in `Scripts/iphone/` run offline and deterministic.
- `APIClient`: `async` `get<T: Decodable>(_ path:)` / `post`, the standard headers from §4.1, `waitsForConnectivity = false`, per-call timeout, `JSONDecoder` with ISO8601 dates. No third-party libraries.
- **Tests:** headers present and correct (URLProtocol stub); non-2xx → typed error; decoding of the bootstrap example fixture.

#### Task B5.2 — Pure models: Bootstrap, UpdateDirective, RolloutBucket, FeatureFlags, Tuning
- [x] done
- **Touches:** `Models/Backend/{Bootstrap,UpdateDirective,RolloutBucket,FeatureFlags,Tuning}.swift`, `Models/Game/CoinRewards.swift` call sites, fixtures, tests.
- `Bootstrap`: Codable mirror of §4.2 (everything optional except `serverTime` and `ttlSeconds`). Unknown enum → `.unknown`.
- `UpdateDirective.decide(build:policy:)` per §4.4, tested with `update-policy-vectors.json`.
- `RolloutBucket.bucket(installId:key:)` FNV-1a, tested with `rollout-vectors.json` (the server decides flags; the app uses this for B9 sampling).
- `FeatureFlags`: `enum FlagKey: String { case shop, dailyChallenge, micInput, coinStore, reviveInDaily, packStore }` with code defaults; `isOn(_:)` reads the latest bootstrap's `flags`, else the default.
- `Tuning`: typed accessors such as `Tuning.int("coins.perNewStar", default: CoinRewards.perNewStar, range: 0...1000)`; out-of-range or wrong type → default. Route the reward call sites through `Tuning` while keeping the `CoinRewards` constants as the defaults, so nothing changes offline.
- **Tests:** the vectors; a malformed tuning value falls back; missing flags fall back.

#### Task B5.3 — BootstrapService (fetch, cache, refresh)
- [x] done
- **Touches:** `Services/Backend/BootstrapService.swift`, `MelodissimoApp.swift`, tests.
- `ObservableObject` singleton: `@Published private(set) var current: Bootstrap?`, `@Published private(set) var directive: UpdateDirective`, `maintenance`.
- Disk cache `Application Support/Backend/bootstrap.json`. `loadCached()` at init (sync). `refresh()` per §5.1: 1.5 s timeout on first launch, 8 s otherwise; skipped if fresher than `ttlSeconds`; never runs while `PlaySession.isActive`. It observes `UIApplication.willEnterForegroundNotification` itself (it lives in `Services/`, so importing UIKit is fine).
- The directive is recomputed from the cached `update.policy` and the current build, even offline.
- **Tests:** cache round-trip; offline uses the cache; a hard directive from the cache with no network; TTL respected.

#### Task B5.4 — ⚠︎ Update gate & maintenance UI
- [x] done
- **Touches:** `Views/Backend/{ForceUpdateView,SoftUpdateSheet,MaintenanceView}.swift`, `CoordinatorView` (find it with `grep -rn "struct CoordinatorView"`), `id.lproj/Localizable.strings`.
- Hard → `ForceUpdateView` as an overlay at the root of `CoordinatorView`. It never interrupts a song: during play, set a pending flag and show the overlay when the play screen closes.
- Soft → `SoftUpdateSheet` on Home only, rate-limited per §4.4.
- Maintenance → a banner on Home that disables server features (pack store). Full screen only if `blocksPlay`.
- Text: server strings in the current app language, falling back to local strings. Styling follows `GAME_PLAN.md` §4 rule 4 and the iPhone `Sizing` rules.
- **Manual QA:** `mdm policy set ios --min <build+1> --env staging` → blocking screen; `--recommended` → the sheet appears once; maintenance banner; airplane mode after a hard policy was cached → still blocked; DEBUG can dismiss.

#### Task B5.5 — Wire feature flags into existing features
- [x] done
- Gate the Shop entry (`shop`), the Daily Challenge card (`dailyChallenge`) and mic input in Settings (`micInput`). When a flag is off the feature is hidden, never crashed. Defaults equal today's behavior, so nothing changes when the server is unreachable.
- **Done when:** toggling each flag on staging changes the app after a foreground refresh.

### Phase B6 — iOS: remote content

#### Task B6.1 — ⚠︎ ContentManifest + ManifestVerifier + ContentStore (read side)
- [x] done
- **Touches:** `Models/Backend/{ContentManifest,ManifestVerifier}.swift`, `Services/Backend/ContentStore.swift`, tests.
- `ManifestVerifier`: `Curve25519.Signing.PublicKey(rawRepresentation:)` with a trusted key list `ManifestVerifier.trustedKeys` (base64 from B4.1); CryptoKit `SHA256` for files, streamed in 1 MB chunks for audio.
- `ContentStore` (`ObservableObject` singleton): `loadActive()` reads `active.json` → manifest → verifies the signature again (cheap) → else falls back to `Data/Content/baseline/` → else empty (the legacy paths still work). API: `songs`, `packs`, `shopItems`, `url(forAsset key:) -> URL?` (downloaded file → baseline file → nil), `manifestVersion`.
- Filters: drop items with `minAppBuild > currentBuild`, unknown `status`/`kind`, and `status == hidden`.
- **Tests:** baseline only; downloaded over baseline; tampered manifest rejected; build-gated item hidden; unknown fields ignored.

#### Task B6.2 — AssetDownloader + staging/activation
- [x] done
- **Touches:** `Services/Backend/AssetDownloader.swift`, `ContentStore.swift`, `BootstrapService.swift`, tests.
- When the bootstrap's `content.version != manifestVersion`: download manifest + sig → verify → download every missing `prefetch` asset (max 3 at once) → verify sha → mark the release staged. Activate per §3.4 #4 (router at Home and `PlaySession.isActive == false`), then send `objectWillChange`.
- `ensureAsset(key) async throws -> URL` for on-demand audio.
- GC per §5.2. Set `isExcludedFromBackup` on the Content folder.
- **Tests:** a release is staged, then activated only when idle; a sha mismatch discards the release and keeps the old one; a rollback to a lower version is accepted.

#### Task B6.3 — ⚠︎ Songs come from ContentStore
- [x] done
- **Touches:** `Models/Music/SongLibrary.swift`, `Models/Music/SongChart.swift`, `Services/BackingTrackPlayer.swift`, `Views/Song/Learn/SongLearnView.swift` and every other view that shows `notationImage`, `Views/Stage/StageSetupView.swift` (download progress), tests.
- `SongLibrary.all` becomes: ContentStore songs sorted by `order`, mapped to `Song`; if ContentStore has no songs, today's `LevelFeederModel`-based list. `Song` gains `sheet: SheetSource` (`.asset(name)` / `.file(URL)`) and `packId`. Keep `notationImage` for the 16 legacy songs.
  `SongLibrary.all` is a `static let` today. It must become a computed value backed by a cache that is cleared when ContentStore activates a new pack. Check every caller (`grep -rn "SongLibrary.all"`), including `CloudSync`'s `songTitles` (use `title.canonical`) and `Campaign` (which maps song titles to slugs; the campaign stays code-defined, so every campaign song must exist — add a test).
- `SongChart.load(for:)`: ContentStore chart asset → current bundle lookup → default. Keep the main-thread cache and clear it on pack activation.
- `BackingTrackPlayer.isAvailable/load`: URL from ContentStore → bundle. If the audio isn't downloaded yet, `StageSetupView` shows a download ring and calls `ensureAsset`; offline, the song plays without backing (today's behavior when the file is missing).
- Score sheet: a small `SheetImage` view: `.asset` → `Image(name)`, `.file` → cached `UIImage(contentsOfFile:)`.
- **Tests:** all 16 legacy songs resolve identically with and without the baseline (same `keyIds`, same chart); a remote-only song from a fixture pack appears and has `keyIds == chart.notes.map(\.k)`; all campaign songs are present; trophy keys are unchanged for legacy titles.
- **Manual QA:** play 3 songs offline from a fresh install; publish a chart tweak to staging and see it after relaunch; publish a 17th song and see it in Free Play.

#### Task B6.4 — Shop catalog and products from ContentStore
- [x] done
- Add a `ContentStoreShopSource` (the `ShopCatalogSource` from E1) and point `products` at the manifest too. Fallback order: ContentStore → bundled `Data/Shop/*.json` (E1, E5).
- Art: the `art.*` assets of equipped and owned items are `prefetch`; the rest download when the shop opens (with a placeholder until then). An outfit whose art isn't on disk and has no `bundledArt` is hidden, never shown broken.
- **Tests:** ids identical to today's list when loaded from the baseline; unknown category skipped; an owned item that disappears from the catalog stays owned and equipped (never take away what a player bought).

#### Task B6.5 — Remove duplicated bundle resources
- [ ] done
- Only after B6.3–B6.4 shipped in a TestFlight build and the user checked it. Delete `Data/Charts/*` and `Data/Sound/Backing/*` (now inside `Data/Content/baseline/`). Keep the legacy lookup code for safety, but make the tests read from the baseline. Check that the app size didn't grow.

### Phase I — International (after B6; the contract parts are already in B1/B3/B4)

#### Task I1 — LocalizedText everywhere in the app
- [x] done
- **Touches:** `Models/Backend/LocalizedText.swift` (new), `Models/Shop/ShopItem.swift`, `Models/Backend/{Bootstrap,ContentManifest}.swift`, every view that shows a server/content string, tests.
- `LocalizedText` (Codable as `[String: String]`) with `resolved(preferred: [String]) -> String` per §4.10. Replace all `{id, en}` structs with it. A 3rd language in a fixture must work without code changes.
- **Tests:** fallback chain (`pt-BR` → `pt` → `en` → first); a fixture missing `en` still shows something.

#### Task I2 — Storefront and markets
- [x] done
- **Touches (iOS):** `Services/Backend/APIClient.swift` (`X-Storefront` from `Storefront.current?.countryCode`, cached; listen to `Storefront.updates`), `Models/Backend/Markets.swift` (new, pure filter), `ContentStore.swift`, `ShopCatalog`, tests. **(backend):** `domain/flags.ts` and tuning rules for `country` / `notCountry` / `language`, migration `000x_tuning_rules.sql`, tests.
- Filtering and `featuredIn` ordering per §4.10, in the app (content) and on the server (flags, tuning, announcements; release selection is unchanged).
- **Tests:** the market matrix (include, exclude, unknown storefront, owned item outside its market stays usable); flag and tuning rules by country.

#### Task I3 — ⚠︎ Note labels: not angka, Do-Re-Mi, ABC
- [x] done
- **Touches:** `Models/Music/Note.swift` (`NoteCatalog`), the settings store (`Models/Progress/ProgressStore+Input.swift` or wherever settings live), `Views/Settings/SettingsView.swift`, `Views/Component/TilesComponentView.swift`, `Views/Stage/NotAngkaSheetView.swift`, `Views/Stage/NoteHighwayView.swift`, every view that prints `note.label` (`grep -rn "\.label"`), tests.
- `enum NoteLabelStyle: String { case notAngka, solfege, letters }` with setting key `settings_noteLabelStyle`. **The default follows the language:** `notAngka` for `id`, `letters` for English, `solfege` for languages that use it (`es`, `fr`, `it`, `pt`). The player can change it.
- `NoteCatalog` gets `label(for id:, style:)`: not angka = today's label (1, 2, 3… with octave dots); solfege = Do Re Mi Fa Sol La Si (+ ♯) with octave marks; letters = C D E F G A B (+ ♯) with octave numbers (C4…). **Note ids never change** (they are persisted, see `Note.swift`).
- The score sheet (`NotAngkaSheetView`) draws in the chosen style. The bundled score-sheet images (`Notasi`) exist only in not angka: for other styles, show the drawn sheet instead of the image (or hide the image tab).
- Quiz/Battle modes that ask "which number?" use the same style.
- **Tests:** label tables for all 32 keys in the three styles; default style per language.

#### Task I4 — [USER + executor] App languages and store listing
- [ ] done
- Executor: check that every UI string goes through `Localizable.strings` (nothing hard-coded outside `Text("…")` / `NSLocalizedString`); add a `Localizable.stringsdict` for plurals ("1 heart / 5 hearts"); check that long translations don't break layouts (Xcode's "Double-Length Pseudolanguage" scheme option); make the `Scripts/iphone/` screenshot scripts take a language argument.
- User: choose the next languages (suggestion: Malay first, since the songs and culture are close and melodica is taught in schools there too; then Japanese/Korean/Spanish if world packs sell), get translations, localize the App Store listing ("Melodica" instead of "Pianika" in English), and set availability per country in App Store Connect.
- Fonts: `BalooDa-Regular` covers Latin. For scripts it doesn't cover (Japanese, Korean, Thai, Arabic…), check on device that glyphs fall back to the system font at the same size; if not, pick the font per language.

#### Task I5 — [USER + executor] First world-song pack
- [ ] done
- The user picks 10–15 **public-domain** tunes that children know worldwide (traditional folk songs, nursery tunes, classical themes whose composers died more than 70 years ago; check each one, and record your own backing arrangement). The executor adds them to `content/` as pack `world-1` with English titles plus the other languages available, worldwide `markets` with `featuredIn` everywhere except `IDN`, sold per D1 (pack + Plus). Charts come from the Chart Recorder / backsound pipeline as usual.

### Phase B7 — Monetization (v4.0)

#### Task B7.1 — [USER] Products in App Store Connect
- [ ] done
- Create the subscription group **Melodissimo Plus** with `melodissimo.plus.monthly` and `melodissimo.plus.yearly` (optional free trial, e.g. 7 days, as an introductory offer), and one non-consumable pack (e.g. `melodissimo.pack.daerah_sumatra`), all with ID/EN localizations and review screenshots. Prepare the privacy policy and Terms of Use (EULA) URLs; Apple requires both for subscriptions. Product ids use only lowercase letters, digits, `.` and `_`, so **the same ids work on Google Play**.

#### Task B7.2 — Entitlements + subscriptions (StoreKit 2)
- [x] done
- **Touches:** `Services/Store/StoreService.swift` (from E5), `Services/Backend/Entitlements.swift`, `Models/Backend/ContentAccess.swift`, `Data/Shop/products.json` + `Products.storekit` (add the Plus and pack ids from B7.1), tests.
- Build on E5's `StoreService`; don't add a second StoreKit wrapper.
- `Entitlements` (`ObservableObject`): `ownedProductIds: Set<String>` from `Transaction.currentEntitlements` (verified transactions only; for subscriptions this already means currently active), plus `plusStatus` (`none / active(renews: Date?) / gracePeriod / expired`) from `Product.SubscriptionInfo.status` for the Settings screen. It listens to `Transaction.updates` from launch and caches the set in UserDefaults `entitlements_cache` for offline launches (re-checked when StoreKit answers).
- `StoreService.buy(productId)` (E5) handles non-consumables and subscriptions too: finish transactions, handle `.pending` (Ask to Buy on family accounts) with a friendly "waiting for approval" state; `restore()` → `AppStore.sync()`.
- `ContentAccess` per §5.3; an active Plus subscription unlocks every pack.
- Settings gets a "Melodissimo Plus" row: status, renewal date, and "Manage subscription" (`AppStore.showManageSubscriptions(in:)`).
- **Tests:** the ContentAccess matrix (free, pack owned, Plus active, Plus expired with pack owned, Plus expired without); Entitlements cache logic (StoreKit itself is checked manually, or with `SKTestSession` if it works on iOS 16.6).

#### Task B7.3 — ⚠︎ Paywalls and pack store
- [x] done
- No parental gate (D2): Buy goes straight to Apple's purchase sheet.
- `PlusPaywallView`: what Plus includes (every pack now and future songs), monthly and yearly options with prices from `Product.displayPrice` and the yearly saving computed from the two prices, trial text if the introductory offer applies (`Product.SubscriptionInfo.isEligibleForIntroOffer`), Subscribe, Restore, and links to the Terms of Use and privacy policy (required by App Review 3.1.2).
- `PaywallView` for a pack: art, song list (titles + a 15 s preview from the backing track if downloaded), localized price from `Product.displayPrice`, Buy, Restore, and a "Get everything with Plus" button that opens `PlusPaywallView`. No countdowns or pressure copy: the players are kids.
- `PackStoreView`, reachable from Free Play and Home, behind the flag `packStore`.
- Locked songs show a lock badge in Free Play; tapping one opens the paywall. The campaign is never locked.
- **Manual QA:** buy a pack and subscribe with the StoreKit config; Ask to Buy pending; restore on a second simulator; offline launch keeps unlocked songs; let Plus expire (StoreKit test time-rate) → Plus-only songs lock, the bought pack stays open; refund in the StoreKit test environment → that song locks again.

#### Task B7.4 — Publish the first paid pack
- [ ] done
- **[USER]** provides the songs (charts via the Chart Recorder / backsound pipeline, score sheets, backing tracks). The executor adds them to `content/` with pack `daerah-sumatra` and its `access.productIds`, publishes to staging, checks the full purchase flow in a TestFlight sandbox build, then lists the production commands for the user.

### Phase B8 — Accounts, cross-platform progress, server entitlements

#### Task B8.1 — ⚠︎ Player identity
- [ ] done
- D1 `0003_players.sql`: `players(id TEXT PK, created_at, last_seen_at)`, `player_devices(player_id, install_id, platform, created_at)`, `player_links(player_id, provider ('apple'|'google'), subject, created_at, UNIQUE(provider, subject))`.
- `POST /v1/players` (anonymous) → `{ playerId, token }`; the token is an HMAC-signed JWT (secret `PLAYER_JWT_SECRET`), valid 1 year, refreshed on use.
- `POST /v1/players/link` with a Sign in with Apple identity token (verified against Apple's JWKS, keys cached in KV) → merges the anonymous player into an existing linked player if there is one.
- iOS: Sign in with Apple in Settings; token stored in the **Keychain**. Request no scopes (no email, no name).

#### Task B8.2 — Progress sync endpoint
- [ ] done
- `progress(player_id PK, data_json, updated_at, revision)`. `GET /v1/players/me/progress`; `PUT` with `If-Match: <revision>`.
- The server merge is a port of the `CloudMerge.swift` rules (max / or / streak / keep-local) to TS, with shared vectors generated from the Swift tests. iOS keeps iCloud KVS and adds server sync when signed in; both use the same rules, so they converge.
- **Tests:** merge vectors identical in Swift and TS; concurrent PUT → 409 → the client re-merges.

#### Task B8.3 — Server-verified purchases
- [ ] done
- `POST /v1/purchases/apple` with the StoreKit 2 JWS → verify the x5c chain to Apple Root CA G3 and the signature (WebCrypto) → upsert `entitlements(player_id, product_id, platform, original_transaction_id, status, expires_at, revoked_at)`. App Store Server Notifications V2 webhook `POST /v1/webhooks/apple` handles Plus renewals, expiry, grace period, refunds and revocations, so Plus also unlocks on Android for the same player. Consumable grants move to a server ledger here too (`coin_ledger(player_id, transaction_id UNIQUE, coins, items_json, at)`), which stops double grants across devices and lets signed-in players get purchased coins back after a reinstall.
- `GET /v1/players/me/entitlements` → union across platforms. The app unions server entitlements with local StoreKit ones.
- Google Play verification comes in B10 with the Android client (or switch to RevenueCat, D4).

### Phase B9 — First-party analytics

#### Task B9.1 — Events pipeline
- [x] done
- `POST /v1/events` with body `{ events: [{ name, at, props }] }` (≤ 50 per batch), schema-validated, written to **Workers Analytics Engine** (dataset `melodissimo_events`). Allowed `name`s are an enum in `events.schema.json`: `app_open, stage_start, stage_end, song_perform_end, shop_buy_coins, paywall_view, purchase_success, purchase_pending, revive_used, coins_purchased, shop_item_bought, content_activated, content_verify_failed, update_prompt_shown`.
- The install id (random UUID, D7) may be sent so funnels can be counted per install; no device identifiers (IDFA/IDFV), no names or emails. Props stay coarse (song id, stars, mode, build, app language, storefront country). Sampling uses `RolloutBucket`. Update the App Store privacy label to "Usage Data, not linked to you, not used for tracking".
- iOS `Analytics.log(_:props:)` buffers to disk, flushes on background or every 20 events, and does nothing when the flag `analytics` is off.
- **[USER]** reads results with the Analytics Engine SQL API; the executor adds `mdm stats funnels` with a few saved queries (paywall → purchase, stage completion by song).

### Phase B10 — Android readiness

#### Task B10.1 — Contract codegen + Android client spec
- [ ] done
- Add `pnpm --filter contracts gen:kotlin` (quicktype → Kotlin `kotlinx.serialization` data classes) and `gen:swift` (quicktype → Swift Codable). Compare the generated Swift with the hand-written models and switch to the generated ones if they're equivalent.
- Write `docs/ANDROID_CLIENT.md`: module layout (`:core:network` with Ktor/OkHttp, `:core:content` porting ContentStore with the same storage layout and resolution order, `:core:billing` with Play Billing, `:feature:*`); the launch sequence from §5.1; the Play **In-App Updates** API for the hard/soft UI, **driven by our policy**; the same shared vectors as tests; the same product ids; `X-App-Platform: android`.
- Add the Google Play purchase verification route `POST /v1/purchases/google` (Play Developer API with a service account), or document the RevenueCat switch.

### Phase B11 — Stretch

- [ ] B11.1 Admin web UI (Cloudflare Pages + Access) over the admin API: policies, flags, releases with a rollout slider, announcements, audit log.
- [ ] B11.2 Remote campaign: move `Campaign.chapters` into content (`campaign.json`, schema v2, gated by `minAppBuild`). Old builds keep getting schema v1 releases.
- [ ] B11.3 Live events: time-boxed challenge playlists with special rewards, via `announcements` + `tuning`.
- [ ] B11.4 Plus extras: monthly "new song" drops on a schedule (announcement + content release), Plus-only cosmetics in the shop.

---

## 8. Operations cookbook (for the user)

| Goal | Command |
|---|---|
| Force iOS users below build 60 to update | `pnpm mdm policy set ios --min 60 --env production` |
| Kill one broken build | `pnpm mdm policy set ios --block 58 --env production` |
| Suggest updating | `pnpm mdm policy set ios --recommended 61 --env production` |
| Fix a chart | edit `content/songs/<slug>/chart.json` → `pnpm mdm content publish --env staging` → test → `--env production` → `pnpm mdm release promote <v> --percent 10 --env production` → later 100 |
| Undo a bad content release | `pnpm mdm release rollback <v> --env production` |
| Turn the shop off now | `pnpm mdm flag set shop --off --env production` |
| Double daily coins for Merdeka week | `pnpm mdm tuning set coins.dailyBase 100 --env production` (set it back afterwards) |
| Maintenance | `pnpm mdm maintenance on ios --text en="…" --text id="…" --env production` |
| Show a pack only in Malaysia + Singapore | set `markets.include: ["MYS","SGP"]` on the pack in `content/packs.json` → publish |
| See everything that's live | `pnpm mdm status --env production` |

**Monthly cost at launch (estimate):** Workers Paid $5 + R2 storage < $1 (≈ 1 GB) + D1/KV within included quotas ≈ **$6/month**. R2 egress is free.

**Release checklist for an app build:** bump `CFBundleVersion` (an integer that always increases) → `mdm content export-baseline` so the bundle carries the newest content → TestFlight → once the build is live and adopted, consider raising `recommendedBuild`. Raise `minSupportedBuild` only for real breakage, or long after a release.

---

## 9. Executor notes

_(Executors record decisions, deviations and the user's answers to §1 here.)_

- **2026-10-15, E3:** "Reset progress" still resets `coins_spentTotal` (as today) and keeps `coins_purchasedTotal`, so after a reset the purchased coins are spendable again while the shop items bought with them are gone. `CloudSync.forgetProgress()` now skips keys a reset keeps, so paid things also stay in iCloud. `buyConsumable` takes `maxStack` as a parameter (default 99) until E1 adds `ShopItem.maxStack`. The settings reset texts changed ("What you bought with real money stays.").
- **2026-10-15, B1.1:** the backend repo is `/Users/macbook/Documents/Coding/melodissimo-backend` (own git repo, branch `main`). Schemas use relative `$id`s (`common.schema.json`, …) because the domain (D6) isn't chosen. `song.title` allows the extra `canonical` key. Generated TS types are one file per schema under `contracts/src/types/` (namespaced exports, e.g. `Manifest.Song`). `git lfs` isn't installed on this Mac yet: only `.gitattributes` is in place, so install it before B1.2 adds audio. pnpm 12 needs `allowBuilds: {esbuild: true}` in `pnpm-workspace.yaml`. Chart vectors in `contracts/examples/charts/index.json` carry `valid` (all rules) and `schemaValid` (schema only); B4.2 tests the `valid` column.
- **2026-10-16, E1:** `Data/Shop/shop.json` keeps today's names in both languages (so the UI reads exactly as before through `LocalizedStringKey`), except the three "Default" items (`Bawaan`/`Default`). `ShopCatalog.items` returns **every** decoded item (so owned or equipped items are always found); the shop page uses `visibleItems(in:owned:)` (on sale, plus owned, plus free defaults) and tabs come from `visibleCategories`. `ShopItem.name` is now computed from `names: LocalizedText` (a minimal `LocalizedText` landed early in `Models/Backend/`; I1 extends it). `ShopCategory.equippable` excludes `boost`; `buy(_:)` refuses consumables. `ShopCatalog.currentBuild` is `Int.max` when `CFBundleVersion` can't be read. The old static list now lives in `ShopCatalogDataTests.legacy`.
- **2026-10-16, E2:** `AlpanicaOutfit` is now a struct built from the equipped `ShopItem` (`AlpanicaOutfit(item:fileURL:)`); outfit entries in `shop.json` carry `bundledArt` (preview + overlay names). `Design/generate_assets.py --png [--out DIR] [--only a,b]` is written but **not run**: this Mac has neither `cairosvg` nor `rsvg-convert`, so the first run needs `pip install cairosvg` or `brew install librsvg`. The overlay-on-every-pose check in `Design/gallery.html` is a manual step.
- **2026-10-16, E4:** revive is a `ReviveRun` object (pure, `Models/Game/Revive.swift`) that a view model holds; view models pause by phase (`awaitingContinue`), not by a clock object (they already take `now`). The coin button on an unaffordable `ContinueSheet` pushes the existing Shop route; it should open the Koin section once E6 exists. `Revive.isPlusMember` is a closure stub that B7.2 replaces; `ReviveRules.defaults` will be fed from `Tuning` in B5.2. ResultRecorder caps stars after a revive for every mode and skips Game Center only for Melody Rush. Not checked by hand: the sheet on iPad/iPhone, lose-and-continue in each mode.
- **2026-10-16, E5:** the `iap_granted` ledger holds `<productId>:<transactionId>` entries (not bare transaction ids) so `oncePerPlayer` can be answered from one key; it still merges as a union. A transaction whose product id this build doesn't know is left **unfinished** so a newer build can grant it. Paid inventory grants ignore the stack limit. The `.storekit` file is wired into the Debug scheme (`Melodissimo/Store/Products.storekit`, IDN storefront, prices Rp 15.000 / 49.000 / 119.000 / 15.000). StoreKit flows (buy, kill before finish, Ask to Buy, failure) are **not exercised yet**: they need a manual pass with the Debug scheme.
- **2026-10-16, E6:** `Route.shopCoins` opens the shop at the Coins tab (coin badge on Home, the badge in the shop, the Continue sheet). `boost_heart` (50 coins, max 99) was added to `shop.json`. Tabs are data-driven (`ShopTab`); the `coinStore` flag hook comes with B5.5, and `plusOnly` badges with B7.3. Seen in the simulator: the shop opens with the new tabs; iPhone layout and buying flows are not checked by hand.
- **2026-10-16, B1.2:** `git lfs` was installed with `brew install git-lfs` (hooks set in the backend repo only, `git lfs install --local`). The `mdm` package exists now (`tools/mdm`, run with `pnpm mdm …`, paths on the command line are relative to where it was run). 5 of the 16 songs have no `Notasi` sheet image in the app (`api-kemerdekaan`, `bangun-pemudi-pemuda`, `bhinneka-tunggal-ika`, `gugur-bunga`, `mars-harapan-bangsa`), so their `sheet.png` is absent: the sheet is optional in the contract and `mdm content import-ios` reports them instead of failing. `content/packs.json` and `products.json` use the `{ packs: [] }` / `{ products: [] }` wrapper shapes.
- **2026-10-16, B2.1:** Worker, middleware, ESLint/Prettier and CI are in `melodissimo-backend`; `pnpm -r lint && pnpm -r typecheck && pnpm -r test` is green. Vitest is pinned to `~3.0` for `@cloudflare/vitest-pool-workers@0.8`. `wrangler.toml` has placeholder ids (`FILL_ME_*`) for staging and production. **B2.2 is half done:** `api/scripts/provision.md` and `deploy.yml` are written; **the user still has to run the provisioning** (the checkbox for B2.2 stays open until `https://api-staging.<domain>/health` answers).
- **2026-10-16, B3:** Workers forbid `new Function`, which ajv uses to compile validators, so the Worker uses **precompiled standalone validators** (`contracts/src/standalone/`, generated by `pnpm --filter contracts gen`; formats are not checked there) imported as `contracts/standalone`; Node tools keep the runtime ajv in `contracts`. `admin.schema.json` was added (strict request bodies). The first publish: `POST /admin/publish` (new endpoint, also run by any admin write) because bootstrap answers 503 `not_ready` until a snapshot exists in KV. New var `CDN_BASE_URL` builds manifest URLs. `mdm` reads `MDM_API_URL_<ENV>` / `MDM_ADMIN_TOKEN_<ENV>`; `flag set` keeps unspecified fields. Verified end to end against local `wrangler dev` (build 1 with `--min 2` → `"action":"hard"`). **Not done:** "deployed to staging" in B3.2, because there is no Cloudflare account/domain wired yet (B2.2, user).
- **2026-10-16, B4:** signing key `k1` was generated on this Mac at `~/.melodissimo/keys/k1/` (private key mode 600). **The user must back it up in a password manager and put it in the GitHub secret `CONTENT_SIGNING_KEY`**; it is not in any repo. Its public key (for `ManifestVerifier.trustedKeys`) is `hevy2AlVbLD9oSzDtvvtrTC1DmAASzQUi5sE24uv2DI=`. Ed25519 uses `node:crypto`, not `@noble/ed25519`. `validate` and `build` are in `tools/mdm/src/lib/{validate,build}.ts`; builds are deterministic when `createdAt` is fixed (default: `SOURCE_DATE_EPOCH`, else now; the baseline uses the epoch). Shop art files are `content/shop/art/<itemId>.preview|overlay.png`, pack art is `content/packs/art/<packId>.png`. `content/release.json` (optional) sets `schemaVersion` and `minAppBuild`. `publish` needs `R2_ENDPOINT`, `R2_ACCESS_KEY_ID`, `R2_SECRET_ACCESS_KEY` and was **not run against real R2/staging** (no account yet): it is covered with an in-memory store. The baseline (`Melodissimo/Data/Content/baseline/`, version 0, 43 assets, ~12 MB) is exported and committed; Xcode flattens bundle resources, so `ContentStore` must find baseline assets by `<sha>.<ext>` at the bundle root as well as in `baseline/assets`. **From now on new songs and chart fixes are made in `melodissimo-backend/content/`.**
- **2026-10-16, B5.1/B5.2:** until the domain (D6) is chosen the build settings point at `*.example.invalid`; `BackendEnvironment.isEnabled` is false for any `.invalid` host, so nothing is contacted and the app runs on defaults. Replace `MELODISSIMO_API_BASE` / `MELODISSIMO_CDN_BASE` in the app target's Debug/Release build settings once the domain exists (Debug can also use `-apiBase <url>`). Fixtures in `MelodissimoTests/Fixtures/` are copies of the backend's `contracts/examples/` (bootstrap, vectors, manifest, signature): re-copy them when the contracts change. `Tuning.reviveRules()` now feeds `ReviveRun.forPlay` and `ResultRecorder`, and `CoinRewards` reads `Tuning` with its constants as defaults. `Tuning`/`FeatureFlags` take their data from `source` closures that `BootstrapService` wires in B5.3.
- **2026-10-16, B5.3–B5.5:** `FeatureFlags`/`Tuning` default sources read `LiveConfig` (thread-safe), which `BootstrapService` fills; `BootstrapService.start()` is called from `MelodissimoApp` and does nothing when `BackendEnvironment.isEnabled` is false. The blocking `ForceUpdateView` lives in `CoordinatorView` above the flow and, like the maintenance screen, waits while `PlaySessionState.isActive`; `SoftUpdateSheet` and `MaintenanceBanner` are on Home. The pack-store part of the maintenance banner has nothing to disable yet (B7.3). `micInput` off makes play use touch (`effectiveInputMode`) and hides the Input card; the stored choice stays. `coinStore` hides the Coins tab and makes the coin badge in the shop a plain badge. **Verified by hand in the iPad simulator against a local `wrangler dev`**: `mdm policy set ios --min 99999` made the app show the blocking screen with the server's English text, and the Debug-only dismiss button. Not checked: soft sheet, maintenance banner and iPhone layout.
- **2026-10-16, B6.1/B6.2:** `ManifestVerifier.trustedKeys` holds the public key of `k1`; the bundled baseline verifies with it (a test loads the real baseline: 16 songs, every chart and backing resolves). The baseline is found by `<sha>.<ext>` at the bundle root (Xcode flattens folders), with `Data/Content/baseline` and `assets/` as fallbacks. `ContentStore` is a plain thread-safe class (not `@MainActor`) so `SongLibrary` can read it from anywhere; it posts `.contentStoreDidActivate` on activation. Staging: `ContentSync.sync(to:)` downloads manifest + signature, checks the bootstrap's sha256, the signature, the schema and `minAppBuild.ios`, downloads `prefetch` assets (3 at a time, retries 1/4/16 s, none for 4xx), writes the manifest last and records `staged.json`; the release is activated at the next launch (`loadActive`) or when Home appears with no song playing (`activateStagedIfIdle`). `active.json`/`staged.json` also keep the CDN base so audio can be fetched on demand (`ContentSync.ensureAsset`). GC keeps the two newest manifests plus the active one. `analytics` for `content_verify_failed` is `ContentSync.lastFailure` until B9.
- **2026-10-16, B6.3:** `SongLibrary.all` is now a cached computed value (rebuilt on `.contentStoreDidActivate`, which also clears `SongChart`'s cache) over `SongLibrary.contentStore` (swappable in tests); `SongLibrary.legacyAll` is the old list and the fallback. **A legacy song keeps its legacy `keyIds`** even when its chart differs (the existing failing test shows `Indonesia Raya`'s chart already differs from its melody), so nothing changes for the 16 shipped songs; only new songs take `chart.notes.map(\.k)`. `Song` gained `packId` and `sheet(store:)` (an `ArtSource`, reused instead of a new `SheetSource`); no `SheetImage` view was added because no screen shows the bundled `Notasi` images today (B8 draws sheets from charts). `BackingTrackPlayer.url(for:)` resolves ContentStore → bundle, and `StageSetupView` downloads a missing backing track (`ContentSync.ensureAsset`) with a small progress badge. Not checked by hand: playing 3 songs offline from a fresh install, publishing a 17th song to staging.
- **2026-10-16, B6.4:** `ShopCatalog.source` defaults to `ContentStoreShopSource` (release or baseline, else the bundled `shop.json`) and **adds back any item that shipped with the app but is no longer listed**, so a legacy item a player bought never disappears. A downloaded item whose `art` hasn't arrived and that has no `bundledArt` is hidden (`ShopCatalog.hasArt`). Shop art is not `prefetch` in manifests (`mdm` builds it that way); `ContentSync` fetches art of owned and worn items with a release, and the shop fetches the rest when it opens (`ShopView.fetchMissingArt`). Limitation: an item added **after** launch, bought, and then dropped from the catalog falls back to the default look (its id stays in `shop_owned`); fixing that needs a local copy of owned items. `ProductCatalog.products` reads the release (or bundled file); tests use `ProductCatalog.override`. **B6.5 is not done on purpose**: it needs a TestFlight build with B6.3–B6.4 checked by the user first.
- **2026-10-16, I1/I2:** `LocalizedText` landed with E1 and is used by shop items, the bootstrap, the manifest and `Song.localizedTitles` (`Song.displayTitle` shows it; `title` stays the canonical trophy key). `Markets` (iOS `Models/Backend/Markets.swift`, server `domain/markets.ts`) filters songs, packs, shop items and coin packs; with an unknown storefront the device region (small alpha-2→alpha-3 table) stands in on the app side, the server treats unknown as worldwide-only; owned things are exempt; `featuredIn` only reorders. `X-Storefront` comes from `Storefront.current` and `Storefront.updates` (cached in `UserDefaults` `backend_storefront`). Server: migration `0003_tuning_rules.sql` (several tuning rows per key with rules; `PUT /admin/tuning/:key` takes `rules`, `DELETE …?rules=<json>`; the snapshot's `tuning` is now a list resolved per client by `resolveTuning`), announcements honour `markets`; `mdm tuning set --rule`, `tuning rm`. Not done: the market badge for featured items in the UI, and showing packs by market in a pack store (B7.3).
- **2026-10-16, I3/I4:** `NoteLabelStyle` (`settings_noteLabelStyle`, default by first language: `id` not angka, `es/fr/it/pt` solfege, else letters) and `NoteCatalog.label(for:style:)`/`displayLabel(_:)`. Solfege keeps the octave dots (`Do˙`, `Sol.`); letters use scientific pitch (`C4` = middle C = not angka `1`). Applied to the on-screen key labels, falling note labels, Battle/Echo prompts, mic calibration, the drawn score sheet and the "Spot Fals's note" quiz choices (the generator still keeps the not angka text as each choice's identity, so quiz tests are unchanged). The learning screens that teach not angka draw keys through the same tile labels, so they follow the setting too. The bundled `Notasi` images are not shown anywhere, so no tab was hidden. **I4 executor part done:** `Localizable.stringsdict` (en, id) for two plural strings, `Scripts/iphone/capture.sh` takes `LANG_CODE=<bcp47>`. **I4 still needs you:** choosing and translating the next languages, App Store listing, the Double-Length Pseudolanguage layout check, and glyph fallback for non-Latin scripts on a device. **I5 is yours** (pick the public-domain songs).
- **2026-10-16, B7.2:** `StoreService` (still the only StoreKit file) now also handles non-consumables and subscriptions (refresh entitlements, then finish; a refunded consumable is finished without a grant), `restore()` (`AppStore.sync()`), `manageSubscriptions()` and `refreshEntitlements()`, which fills `Entitlements` (owned products with expiry + `PlusStatus`; cached in `entitlements_cache`, and a subscription past its end date stops counting even offline). `Revive.isPlusMember` is wired to it. `ContentAccess` is the pure rule (unknown access types stay locked; a pack missing from the release follows `core`). `products.json` and `Products.storekit` got the two Plus subscriptions (group `Melodissimo Plus`, 7-day free trial as an introductory offer, Rp 29.000 / 249.000) and `melodissimo.pack.daerah_sumatra` (Rp 79.000); the same products are in the backend `content/products.json` and the baseline was re-exported. The Settings "Melodissimo Plus" card is hidden until the `packStore` flag is on. A download bug found on the way: a cancelled sibling download no longer retries with backoff. Not exercised against StoreKit (no `SKTestSession` here): buy, Ask to Buy, expiry via the StoreKit test clock, refund.
- **2026-10-16, B7.3:** `PlusPaywallView`, `PaywallView(packId:)` (with a 15 s preview of downloaded backing tracks) and `PackStoreView` are new routes (`.plus`, `.paywall`, `.packStore`), reachable from Home and Free Play only while the `packStore` flag is on. The Free Play song picker (`SongRepositoryQuizView`) was reading the old level list; it now lists `SongLibrary.all` (so songs added by a content release appear) with a grey card and lock for songs whose pack the player doesn't have, and a tap opens that pack's paywall. The campaign is never locked. Prices only come from the store (`StoreService.offer(for:)`), the yearly saving is computed in `PlusPricing`. **You must set** the Terms of Use and Privacy Policy URLs before shipping a build with Plus: build settings `MELODISSIMO_TERMS_URL` / `MELODISSIMO_PRIVACY_URL` (they are `*.example.invalid` placeholders, and the links stay hidden until real). Not checked by hand: the three new screens (only the song picker was seen in the simulator), buying with the StoreKit configuration, Ask to Buy, restore on a second simulator, offline launch, refund.
- **2026-10-16, B9.1:** backend: `POST /v1/events` (≤ 50 events, `events.schema.json`, standalone-validated, answers 202) writes one Analytics Engine data point per event (`EVENTS` binding; dataset `melodissimo_events` in production, `…_staging`, `…_dev`); blob/double column order is fixed in `api/src/domain/events.ts` and mirrored in `mdm` (a test keeps them equal): blob1 event, 2 platform, 3 version, 4 language, 5 storefront, 6… props (`songId, mode, packId, productId, source, stageId, kind, reason`); double1 time, 2 build, 3… `stars, score, coins, revives, won, contentVersion, build`. Migration `0004` adds the flag **`analytics` (off)** and tuning `analytics.sampleRate` (100). `mdm stats funnels --env … [--report paywall|stages|revives]` needs `CF_ACCOUNT_ID` and `CF_ANALYTICS_TOKEN` (Account Analytics: Read). iOS: `Analytics` buffers to `Application Support/Backend/events.json`, flushes at 20 events and when the app goes to the background, caps the buffer at 500, and does nothing unless backend + flag + sample allow it; `RolloutBucket` decides the sample. Events wired: `app_open`, `stage_start`, `stage_end`, `song_perform_end`, `shop_buy_coins`, `coins_purchased`, `shop_item_bought`, `paywall_view`, `purchase_success/pending`, `revive_used`, `content_activated`, `content_verify_failed`, `update_prompt_shown`. **Before switching `analytics` on you must update the App Store privacy label** to "Usage Data, not linked to you, not used for tracking". Not exercised against a deployed Worker.
- **2026-10-15, test baseline:** `SongChartTests.testAllSixteenSongsLoadAChartMatchingTheirMelody` ("Indonesia Raya: chart keys differ from the melody") already fails on a clean checkout of `27ef748`. It is not caused by Phase E work.

- **2026-10-15, D2:** no Kids Category; keep age rating 4+ in Music/Education.
- **2026-10-15, D1:** Melodissimo Plus subscription (monthly + yearly) + one-time song packs, no ads.
- **2026-10-15:** no parental gate anywhere (user's choice).
- **2026-10-15, D8:** the app will go international; language maps and country targeting are part of the contracts from B1.1 (§4.10).
- **2026-10-15:** the shop (including Alpanica outfits) must be extendable from the backend; coin packs (consumable IAP) and hearts bought with coins are in scope (Phase E).
