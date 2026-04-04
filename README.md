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
It gives members a single place to manage their garage, discover community builds, RSVP to meets, browse merch, and stay connected to the club in a clean, club-branded experience.

This repository contains the full Swift source code for the Empire Connect iOS client.

---

## ⚠️ BETA VERSION

> This project is currently in active development.  
> Not yet recommended for production use.

---

## 📌 Why Empire Connect?

Empire Connect gives real car culture a proper digital home:

- User-owned garages and build history  
- Community feed and social discovery  
- Meets, merch, and VIP experiences in one app  
- Visual-first vehicle profiles  
- Club-branded native iOS experience  
- No spreadsheets. No forums. Just builds.  

---

## 📱 Features

- Email/password authentication
- Sign in with Apple
- Google Sign-In
- Password reset and auth callback handling
- First-run onboarding for new members
- Create and manage vehicle profiles with photos
- Vehicle specs, mods, build categories, and stage tracking
- User-scoped garages with local caching and backend sync
- Public community feed with likes, comments, follows, and post sharing
- Upcoming meets, participation flows, and QR check-in support
- Merch browsing, cart flow, and branded catalog surfaces
- VIP membership purchase flow with StoreKit
- Username, avatar, and account management
- Push notification preferences, inbox, and deep link handling
- Branded launch, theming, and immersive SwiftUI UI

---

## 🚀 Technologies Used

Empire Connect is built with performance, persistence, and clean UI in mind.

### iOS App
- **Swift**
- **SwiftUI**
- **SwiftData** (local cache + app data persistence)
- **FileManager** (local image storage)
- **UserDefaults** (session/app flags)
- **StoreKit** (VIP membership purchase flow)
- **GoogleSignIn**
- **UserNotifications / APNs**

### Backend
- **Supabase Auth** (email/password + social auth handoff)
- **Supabase PostgREST** (cars, profiles, community, meets, merch, and notification data)
- **Supabase Storage** (car photos, community media, and avatars)
- **Supabase Edge Functions** (push notification rollout in `supabase/`)

### Testing & Observability
- **XCTest** unit and UI coverage for auth, vehicles, stages, merch mapping, profile stats, and launch flows
- Structured telemetry and OSLog-backed logging for performance and error tracking

---

## 🛠️ How It Works

1. **Users authenticate** with email/password, Apple, or Google and receive a user-scoped session  
2. **Garage data** including vehicles, specs, mods, and profile details syncs with Supabase  
3. **Media** for cars, avatars, and community posts uploads to Supabase Storage and is reused through transformed URLs  
4. **SwiftData** and local persistence keep core views responsive between refreshes  
5. **Community, meets, merch, and notifications** refresh on app lifecycle events and support deep links back into the app

This ensures cars are:
- Persistent  
- User-scoped  
- Offline-safe

---

## ✅ Current Status

- Core garage, profile, community, meets, merch, and VIP flows are present in the iOS client.
- Cross-device sync, media upload, and account/profile updates are wired through Supabase.
- Push notification infrastructure is scaffolded in `supabase/` and connected to in-app preferences and inbox surfaces.
- The project currently targets **iOS 26.0** and remains in active beta development.

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
