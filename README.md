# ReplyGenius — Calm AI co-pilot for customer replies

ReplyGenius is an Android app (built in Flutter with a native Kotlin extension) that listens for incoming WhatsApp and SMS messages from your customers, analyzes their emotional state, and instantly drafts calm, skillful, well-trained reply suggestions that pop up as a floating bubble over your chat — ready to copy and paste.

It is built for small business owners who are great at what they do but don't always have the marketing or issue-management skills to defuse angry customers gracefully.

## Why this app exists

When a customer is angry, the natural human reaction is to get defensive, argue, or freeze. ReplyGenius replaces that reflex with a calm, trained reply — written by an AI that has been specifically trained on *your* business: your policies, your tone, your do's and don'ts, your FAQ knowledge.

The result: issues get resolved faster, customers feel heard, reviews stay positive.

---

## Architecture at a glance

```
┌─────────────────────────────────────────────────────────────────┐
│  Flutter app (Dart)                                             │
│                                                                 │
│  ┌──────────────┐    ┌────────────────┐    ┌─────────────────┐  │
│  │ Onboarding   │ →  │ Business       │ →  │ ReplyEngine     │  │
│  │ (5-step      │    │ ContextService │    │ (orchestrator)  │  │
│  │  wizard)     │    │ (builds system │    │                 │  │
│  │              │    │  prompt)       │    │ Listens to:     │  │
│  │              │    │                │    │  NativeBridge   │  │
│  │              │    │ "Training":    │    │  (EventChannel) │  │
│  │              │    │  - identity    │    │                 │  │
│  │              │    │  - tone        │    │ Calls:          │  │
│  │              │    │  - policies    │    │  GeminiService  │  │
│  │              │    │  - do/don't    │    │  (Gemini 1.5    │  │
│  │              │    │  - FAQ KB      │    │   Flash)        │  │
│  │              │    │  - philosophy  │    │                 │  │
│  │              │    │  - output rules│    │ Pushes:         │  │
│  │              │    │                │    │  → Overlay via  │  │
│  │              │    │                │    │    NativeBridge │  │
│  └──────────────┘    └────────────────┘    └─────────────────┘  │
│                                                                 │
└──────────────────────────┬──────────────────────────────────────┘
                           │ MethodChannel + EventChannel
                           ▼
┌─────────────────────────────────────────────────────────────────┐
│  Native Android extension (Kotlin)                              │
│                                                                 │
│  ┌──────────────────────────┐    ┌──────────────────────────┐   │
│  │ NotificationListener     │    │ OverlayService           │   │
│  │ (NotificationListener    │    │ (foreground service,     │   │
│  │  Service)                │    │  SYSTEM_ALERT_WINDOW)    │   │
│  │                          │    │                          │   │
│  │ Captures WhatsApp & SMS  │    │ Draws the floating       │   │
│  │ notifications, extracts  │    │ bubble over the active   │   │
│  │ sender + text, pushes    │    │ chat. Tap to expand,     │   │
│  │ via IncomingMessageBus   │    │ tap a variant to copy.   │   │
│  └──────────────────────────┘    └──────────────────────────┘   │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## The "training" logic — what makes replies good

ReplyGenius does NOT send a free-form prompt to Gemini. It constructs a rich,
layered system prompt from your business profile. The `BusinessContextService`
builds this prompt with 8 layers:

1. **Identity** — Business name, industry, description. Gives the AI its "I am…"
2. **Brand voice** — Tone (calm/professional/friendly), apology style (soft/corporate/warm), plus an optional sample of how *you* write that the AI mimics.
3. **Core philosophy** — The calm-mind playbook: never argue, never get defensive, always acknowledge emotion first, then propose a concrete next step.
4. **De-escalation playbook** — A 5-step structure: Acknowledge → Apologize → Align → Act → Assure. Plus a banned-phrase list ("unfortunately", "as per our policy", "kindly do the needful").
5. **Policies** — Refund, shipping, contact, escalation — hard guardrails the AI must respect and cannot invent around.
6. **Do's & Don'ts** — User-defined rules ("always offer 10% coupon for repeat issues", "never promise full refund without owner approval").
7. **FAQ knowledge base** — User-defined Q&A pairs. The AI leans on these facts.
8. **Output rules** — Format constraints: 1-4 sentences, contractions, max one emoji, no placeholders, no "I am an AI" disclaimers, escalation handling.

Every incoming customer message triggers:
1. **Sentiment analysis** — A lightweight Gemini call returns anger score 1-5 and a one-line summary.
2. **System prompt rebuild** — Done fresh on every message (so profile changes take effect immediately).
3. **Variant generation** — 2 reply variants in different styles (calm / action-oriented) so the user can pick.
4. **Push to overlay** — Variants sent to the native OverlayService which draws the floating bubble.

---

## Permissions required

| Permission | Purpose |
|------------|---------|
| `BIND_NOTIFICATION_LISTENER_SERVICE` | Native NotificationListenerService reads WhatsApp/SMS notifications |
| `SYSTEM_ALERT_WINDOW` | OverlayService draws the reply bubble over WhatsApp/SMS |
| `INTERNET` | Calls to Gemini API |
| `READ_SMS` / `RECEIVE_SMS` | (Optional) Direct SMS inbox parsing fallback |
| `FOREGROUND_SERVICE` + `FOREGROUND_SERVICE_SPECIAL_USE` | Keeps the overlay service alive while bubble is shown |
| `POST_NOTIFICATIONS` | Android 13+ foreground notification |
| `VIBRATE` | Haptic feedback on escalation alerts |

The user must grant Notification Access and Draw-over-other-apps manually in Android Settings. The app's Home screen shows a permission sheet on first launch with deep links to both settings pages.

---

## Project structure

```
replygenius/
├── pubspec.yaml
├── lib/
│   ├── main.dart                              # App entry, providers, routing
│   ├── models/
│   │   ├── business_profile.dart              # "Training" data model
│   │   ├── customer_message.dart              # Incoming message
│   │   ├── faq.dart                           # FAQ entry
│   │   ├── reply_history.dart                 # Saved reply record
│   │   └── reply_variant.dart                 # Generated reply variant
│   ├── services/
│   │   ├── business_context_service.dart      # SYSTEM PROMPT BUILDER (training logic)
│   │   ├── gemini_service.dart                # Gemini 1.5 Flash API client
│   │   ├── history_service.dart               # SQLite reply history
│   │   ├── native_bridge_service.dart         # Method/Event channels to Kotlin
│   │   ├── reply_engine.dart                  # Orchestrator (listen → analyze → generate → push)
│   │   └── storage_service.dart               # SharedPreferences + SecureStorage
│   ├── screens/
│   │   ├── onboarding_screen.dart             # 5-step business training wizard
│   │   ├── home_screen.dart                   # Dashboard + permission sheet
│   │   ├── business_profile_screen.dart       # Edit training data
│   │   ├── faq_screen.dart                    # Manage FAQ knowledge
│   │   ├── tester_screen.dart                 # Simulate angry messages in-app
│   │   ├── history_screen.dart                # Past replies
│   │   └── settings_screen.dart               # API key, permissions, status
│   ├── utils/theme.dart                       # Material 3 theme
│   └── widgets/sentiment_badge.dart           # Anger 1-5 badge
└── android/
    └── app/src/main/
        ├── AndroidManifest.xml                # All permissions + service declarations
        ├── kotlin/com/replygenius/app/
        │   ├── MainActivity.kt                # Flutter activity + channel handlers + IncomingMessageBus
        │   ├── NotificationListener.kt        # Captures WhatsApp/SMS notifications
        │   └── OverlayService.kt              # Floating bubble foreground service
        └── res/                               # Launcher icons, styles, strings
```

---

## How to build & run

### Prerequisites
- Flutter 3.22+ (`flutter --version`)
- Android SDK 34 + Android NDK (managed by Flutter)
- A physical Android device (recommended) or emulator with API 23+
- A Gemini API key from https://aistudio.google.com/app/apikey (free tier is generous)

### Steps

```bash
# 1. Install dependencies
cd replygenius
flutter pub get

# 2. Plug in your Android device (USB debugging ON) or start an emulator
flutter devices

# 3. Run in debug
flutter run

# 4. Build a release APK
flutter build apk --release
# Output: build/app/outputs/flutter-apk/app-release.apk
```

### First-run setup (in the app)

1. **Onboarding wizard** — Walk through 5 steps: business identity, tone, policies, do's & don'ts, Gemini API key.
2. **Permission sheet** — On the Home screen, tap each permission row:
   - **Notification access** → toggle on "ReplyGenius" in Android Settings.
   - **Draw over other apps** → grant "Display over other apps".
3. **Test a reply** — Open the "Test a reply" tile from Home. Type an angry customer message ("This is the third time my order arrived broken!") and tap **Generate reply**. You'll see the anger badge + 2 reply variants.
4. **Live test** — Open WhatsApp on the same phone. Have someone send you an angry message. A floating "✨ Reply" bubble should appear at the top-right. Tap a variant to copy it, then paste into WhatsApp.

---

## Native extension — how the listener survives app kills

The `NotificationListenerService` is started and managed by Android's notification subsystem, NOT by the Flutter app process. This means:

- It survives app kills (swipe-away from recents).
- It restarts automatically after device reboot.
- It keeps capturing messages as long as the user has "Notification access" toggled on.

The `OverlayService` is a foreground service — it runs only while a bubble is visible, then shuts down to save battery.

For IPC between the listener and Flutter, we use a tiny static `IncomingMessageBus` (in `MainActivity.kt`) that holds the active `EventChannel.EventSink`. The listener pushes messages there; the sink posts them to the Flutter side on the main looper.

---

## Customization

### Adding more channels (Instagram DM, Telegram)
Edit `NotificationListener.kt` and add the package name to the `when` block in `onNotificationPosted`:

```kotlin
"com.instagram.android" -> "instagram"
"org.telegram.messenger" -> "telegram"
```

The rest of the pipeline (sentiment → variants → overlay) is channel-agnostic.

### Switching AI backend (OpenAI, custom endpoint)
Replace `lib/services/gemini_service.dart` with an OpenAI-compatible client. The interface is:

```dart
Future<List<Map<String, dynamic>>> generateReplies({
  required String systemPrompt,
  required String customerMessage,
  required String conversationHistory,
  int variantCount = 2,
});

Future<({int angerScore, String summary})> analyzeSentiment(String message);
```

### Increasing reply variants
Change `variantCount: 2` to `3` or `5` in `lib/services/reply_engine.dart` (`_handleIncoming`).

---

## Privacy

- The Gemini API key is stored in `flutter_secure_storage` (encrypted at rest by Android Keystore).
- Business profile & FAQs are stored in `SharedPreferences` (plain text, no secrets).
- Reply history is in a local SQLite DB.
- Messages are sent directly from your device to Google's Gemini endpoint. No intermediate server.
- No analytics, no telemetry, no third-party trackers.

---

## Known limitations (v1)

- **Conversation context** — v1 generates replies for a single incoming message without prior chat history. v2 will maintain a per-sender conversation buffer.
- **Auto-paste** — Currently the overlay copies the reply to clipboard; the user pastes manually. Auto-typing via AccessibilityService is roadmap (and requires another permission).
- **Voice input** — Roadmap. The onboarding wizard is text-only today.
- **Multi-language** — v1 is English-only. Roadmap: Hindi, Hinglish, auto-detect.

---

## Roadmap

- [ ] Per-sender conversation memory (last 5 messages)
- [ ] AccessibilityService for auto-typing replies
- [ ] Escalation alerts (vibrate + push notification) when anger=5 or keywords detected
- [ ] Pre-built templates library (refund, delay, defect, wrong item, etc.)
- [ ] Hindi + Hinglish reply support
- [ ] Voice input for onboarding
- [ ] Onboarding quick-start presets (e-commerce, restaurant, salon, clinic)

---

## License

Proprietary — built for the ReplyGenius project. No redistribution without permission.
