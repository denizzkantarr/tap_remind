# Tap Remind

> Sesli hatırlatıcı uygulaması / Voice-based reminder app

---

## Türkçe

### Nedir?

Tap Remind, basılı tut butonu ile sesli hatırlatıcı oluşturmanı sağlayan bir Flutter uygulamasıdır. Konuştuğun metin otomatik olarak yazıya çevrilir ve istediğin zamana hatırlatıcı kurulur.

### Özellikler

- **Sesli Not**: Butona basılı tut, konuş, bırak — metin otomatik oluşturulur
- **Hızlı Zamanlama**: +1 Saat, +10 Saat, Yarın 09:00 veya özel saat
- **Bildirimler**: Yerel push bildirim, özelleştirilebilir ses seçenekleri
- **Arşiv**: Tamamlanan ve aktif hatırlatıcıları görüntüle, ses kayıtlarını dinle
- **Dil Desteği**: Türkçe ve İngilizce

### Kurulum

```bash
# Bağımlılıkları yükle
flutter pub get

# Hive model kodlarını üret
dart run build_runner build

# Uygulamayı çalıştır
flutter run
```

### Derleme

```bash
flutter build apk       # Android
flutter build ios       # iOS
flutter build macos     # macOS
flutter build windows   # Windows
flutter build linux     # Linux
```

### Gereksinimler

- Flutter SDK `^3.9.2`
- Android / iOS / macOS / Windows / Linux

---

## English

### What is it?

Tap Remind is a Flutter app that lets you create reminders by pressing and holding a button to speak. Your voice is transcribed automatically and a notification is scheduled for your chosen time.

### Features

- **Voice Input**: Press and hold to speak — text is generated automatically
- **Quick Scheduling**: +1 Hour, +10 Hours, Tomorrow 9AM, or custom time
- **Notifications**: Local push notifications with customizable sound options
- **Archive**: View active and completed reminders, play back audio recordings
- **Localization**: Turkish and English

### Setup

```bash
# Install dependencies
flutter pub get

# Generate Hive model code
dart run build_runner build

# Run the app
flutter run
```

### Build

```bash
flutter build apk       # Android
flutter build ios       # iOS
flutter build macos     # macOS
flutter build windows   # Windows
flutter build linux     # Linux
```

### Requirements

- Flutter SDK `^3.9.2`
- Android / iOS / macOS / Windows / Linux

---

## Tech Stack

| Layer | Technology |
|---|---|
| Framework | Flutter / Dart |
| Storage | Hive |
| Speech-to-Text | speech_to_text |
| Audio Recording | record, audioplayers |
| Notifications | flutter_local_notifications |
| Localization | easy_localization |
