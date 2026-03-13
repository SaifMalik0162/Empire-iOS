# 🏁 Empire Connect

<p align="center">
  <strong>Official iOS App for Empire Auto Club</strong><br/>
  A modern mobile experience for car profiles, builds, and the Empire lifestyle.
</p>

<p align="center">
  <img src="empire-connect-banner.png" alt="Empire Connect Banner" style="width: 100%; max-width: 900px;"/>
</p>

---

**Empire Connect** is the official iOS application for **Empire Auto Club**.  
It allows members to create vehicle profiles, upload car photos, track builds, and manage their garage in a clean, club-branded experience.

This repository contains the full Swift source code for the Empire Connect iOS client.

---

## ⚠️ BETA VERSION

> This project is currently in active development.  
> Not yet recommended for production use.

---

## 📌 Why Empire Connect?

Empire Connect gives real car culture a proper digital home:

- User-owned garages  
- Persistent car builds  
- Visual-first vehicle profiles  
- Club-branded experience  
- No spreadsheets. No forums. Just builds.  

---

## 📱 Features

- Email/password authentication  
- Sign in with Apple  
- Password reset flow  
- Create and manage vehicle profiles  
- Upload and display car photos  
- Vehicle specs, mods, and stage tracking  
- Persistent user-scoped garages with cross-device sync  
- Username + avatar profile management  
- Username change cooldown rules  
- Branded native launch screen and club-themed UI

---

## 🚀 Technologies Used

Empire Connect is built with performance, persistence, and clean UI in mind.

### iOS App
- **Swift**
- **SwiftUI**
- **MVVM architecture**
- **SwiftData** (local cache + offline-friendly persistence)
- **FileManager** (local image storage)
- **UserDefaults** (session/app flags)

### Backend
- **Supabase Auth** (email/password + Apple sign-in)
- **Supabase PostgREST** (cars/specs/mods/meets/merch/profile data)
- **Supabase Storage** (car photos + avatars)

### Testing & Observability
- **XCTest** unit tests for auth/network/merch flows
- Structured telemetry with performance, error, and crash logging hooks

---

## 🛠️ How It Works

1. **Users authenticate** (email/password or Apple) and get a user-scoped session  
2. **Vehicle data** (make/model/specs/mods/stage) syncs with Supabase tables  
3. **Photos** are uploaded to Supabase Storage and cached locally for fast display  
4. **SwiftData** keeps a local cache so garage views remain responsive  
5. On app open/foreground, the app refreshes and reconciles data from backend

This ensures cars are:
- Persistent  
- User-scoped  
- Offline-safe

---

## ✅ Current Status

- Supabase migration is complete for auth, garage data, merch, meets, and media storage.
- Cross-device garage sync and profile updates are live.
- Community-driven featured/feed surfaces are planned next.

---

## 📸 App Screenshots

*(Coming soon)*

---

## 👨‍💻 Core Maintainer

| **Saif Malik** |
|---------------|
| <img src="https://github.com/SaifMalik0162.png" width="150px" /> |
| Founder & Lead Developer, Empire Connect |

---

## 🛠️ Contributing

For contribution guidelines, please refer to:

**`CONTRIBUTING.md`**

---

## 🏎 Empire

Built for drivers.  
Built for builders.  
Built for real car culture.
