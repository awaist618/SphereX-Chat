# SphereX 🌌

**Smart Communication. Connect. Communicate. Act.**

SphereX is a premium real-time communication platform built with Flutter and Supabase. It goes beyond traditional messaging by integrating **Smart Tasks**, allowing users to turn important conversations into actionable items instantly.

---

## ✨ Features

### 🔹 Core Messaging
*   **Real-time Chat:** Instant 1-to-1 and Group messaging powered by Supabase Realtime.
*   **Presence & Presence Tracking:** Live "Online" indicators, "Last Seen" status, and real-time typing indicators.
*   **Rich Media Sharing:** Send images, documents, video notes, and professional voice messages with waveform visualization.
*   **Message Interactions:** Full support for replies, editing, deleting (for self or everyone), and message reactions.

### 🔹 Signature Feature: Smart Tasks 📋
*   **Message-to-Task Conversion:** Long-press any message to convert it into a task.
*   **Assignment & Deadlines:** Assign tasks to yourself or teammates with specific due dates.
*   **Task Dashboard:** A dedicated space to track "Assigned to Me," "Created by Me," and completed tasks.
*   **Contextual Links:** Every task retains a link back to the original message for full context.

### 🔹 Connectivity & Security
*   **Unique Identity:** Users are identified by unique `@usernames`.
*   **Contact System:** Robust search and contact request/approval workflow.
*   **Privacy & Security:** Row Level Security (RLS) ensures users only access data they are authorized to see.
*   **Local Persistence:** Uses SQLite for fast loading and offline access to message history.

---

## 🛠 Tech Stack

*   **Frontend:** Flutter (Dart)
*   **Backend:** Supabase (PostgreSQL, Auth, Realtime, Storage)
*   **Local Database:** Sqflite
*   **State Management:** Provider-like architecture with Service/UI separation
*   **Media Handling:** Dio, Image Picker, Record, Audioplayers, Video Player

---

## 📸 Screenshots

| Welcome Screen | Chat Interface | Smart Tasks |
| :---: | :---: | :---: |
| ![Welcome](https://raw.githubusercontent.com/username/repo/main/screenshots/welcome.png) | ![Chat](https://raw.githubusercontent.com/username/repo/main/screenshots/chat.png) | ![Tasks](https://raw.githubusercontent.com/username/repo/main/screenshots/tasks.png) |

*(Note: Replace URLs with actual screenshot paths after uploading to your repository)*

---

## 🚀 Getting Started

### Prerequisites
*   Flutter SDK (Stable channel)
*   A Supabase project

### Setup
1.  **Clone the repository:**
    ```bash
    git clone https://github.com/yourusername/spherex_chat.git
    cd spherex_chat
    ```
2.  **Install dependencies:**
    ```bash
    flutter pub get
    ```
3.  **Configuration:**
    *   Create a `lib/config.dart` file (this file is ignored by git for security).
    *   Add your Supabase credentials:
    ```dart
    class AppConfig {
      static const String supabaseUrl = 'YOUR_SUPABASE_URL';
      static const String supabaseKey = 'YOUR_SUPABASE_ANON_KEY';
    }
    ```
4.  **Database Setup:**
    *   Run the SQL provided in the `Agent.md` (or database setup guide) in your Supabase SQL Editor to initialize tables and RLS policies.

---

## 📦 Building for Release

To generate an optimized, professional APK under 50MB:

```bash
flutter build apk --release --split-per-abi
```
The resulting files will be located in `build/app/outputs/flutter-apk/`. The `arm64-v8a` version is recommended for most modern devices.

---

## 🛡 Security Note
This project uses **Row Level Security (RLS)** and environment variable protection. Sensitive API keys are never committed to version control. Ensure `lib/config.dart` is added to your `.gitignore`.

---

## 👨‍💻 Author
**SphereX Team**
Connect. Communicate. Turn conversations into action.
