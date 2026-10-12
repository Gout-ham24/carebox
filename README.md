# CareBox Flutter mobile source


```bash
flutter create . --platforms=android
flutter pub get
flutter analyze
flutter test
flutter run
```

You need the Flutter SDK and Android SDK installed, plus an Android device or emulator to run the app. The ZIP contains the complete handwritten app source; `flutter create` supplies the Android platform boilerplate. For LAN HTTP hardware testing, apply the Android manifest edits documented below and use matching ESP8266 firmware. This is a demo and LAN prototype source bundle—not a production Firebase backend, finished hardware product, or included firmware package.

## Export and run the Flutter project

This workspace preserves Dart, YAML, and Firestore rules as `.txt` source files. From this folder, run the standard-library exporter; it safely creates or refreshes the Flutter filenames while retaining all `.txt` source files:

```bash
python export.py
flutter create . --platforms=android
flutter pub get
flutter analyze
flutter test
flutter run
```

The exporter is idempotent: each generated file is derived from its corresponding `.txt` source, and `lib/main.dart` is always regenerated from the untouched original before the deterministic Wi-Fi screen integration is applied. Review generated destinations after exporting because changed sources intentionally refresh them. The Flutter app uses only Flutter SDK libraries, needs no Firebase configuration or credentials, and runs as a local in-memory demo. Data resets when the app process ends.

Open the folder in VS Code, select a device or Android emulator, and run the commands in its integrated terminal. Android notifications are represented by the app's local in-memory notification center in demo mode. For native/local notifications on Android 13+, add `android.permission.POST_NOTIFICATIONS` to `android/app/src/main/AndroidManifest.xml`, request permission after explaining the feature, and integrate a maintained local-notifications plugin. The current demo does not claim OS-level notification delivery.

## Included demo interactions

- Sign-in/register presentation, forgot-password guidance, and one-tap demo entry.
- Patient, primary caretaker, and additional caretaker demo role selection.
- Overview with next dose, daily progress, active response countdown, recent activity, quick actions, and local notification center.
- Configure one medication and reminder time per each of exactly three boxes: Box 1 Morning, Box 2 Afternoon, and Box 3 Evening. Same-day schedules at an identical time are rejected with: `Two medicines are scheduled at the same time. Please choose different times.`
- Today/week/month history with detailed reminder outcomes. In-app acknowledgement is labeled separately from a simulated physical button press; neither confirms medication ingestion.
- Local demo care-circle invitation records and role display; only the primary caretaker can remove members, and the primary caretaker cannot be removed.
- Respectful concern creation, response, resolve, and raise-author withdrawal.
- Simulated LEDs, buzzer, a configurable response countdown (15 minutes by default), offline toggle, and test/reconnect interactions. The device screen warns that these are simulations; its physical-button simulation is explicitly labeled.
- Settings toggles, response-window display, about and sign-out.
- One active reminder at a time. The demo checks enabled schedules each second and starts the first matching day/time once for that minute; starting a reminder turns on simulated LED/buzzer and display status, begins the configurable 5–30 minute response countdown (15 minutes by default), and adds a local activity notice. In-app acknowledgement and simulated physical-button acknowledgement have distinct history labels. Expiry records a missed event and clears indicators. A repeated-miss banner is shown only when missed reminders exceed three in the rolling two-day window; a separate confirmation is required before raising a concern.

## Production Firebase and device integration

Production services are **not connected or implemented in this bundle**. Sign-in, invitations, notifications, and local demo device interactions remain local simulations. An opt-in ESP8266 Wi-Fi prototype screen is exported and reachable through a separate action; the existing local demo toggle remains separate. It requests device status before showing device-reported online state, polls and lists events only while the screen is open, and disposes its connection when closed or disconnected. There is no Firebase Auth, Firestore, FCM, STM32 firmware, or live device gateway included or verified here. Do not treat demo role selection as authentication, local notices as delivered notifications, or successful HTTP responses as proof of physical behavior.

The included Firestore rules text is not deployed or exercised by this local-only Flutter app. It is not evidence of a functioning backend or production security configuration. Production integration requires a separately designed, authenticated backend and device service; do not add secrets to this Flutter source bundle.

## Opt-in ESP8266 LAN prototype contract

The source bundle includes an exported, configurable `WifiDeviceService` HTTP client and an opt-in screen labeled **ESP8266 Wi-Fi prototype**. Open it with **Local demo / Connect ESP8266 Wi-Fi prototype**; it remains separate from the existing local demo mode and toggle. The screen accepts a LAN URL, obscured pairing token, and schedule JSON; it reports request failures and displays events actually received from the device. Connection and event polling are active only while the screen is open and are disposed when it closes or Disconnect is pressed. The exporter derives generated `lib/main.dart` from the original `.txt` source on every run, renames the existing demo screen, adds the opt-in wrapper, and exports the standalone screen. Matching ESP8266 firmware implementing this contract is required. No STM32 connection, firmware, board wiring, Firebase service, physical action, or medication ingestion is claimed or verified. Keep the app's default `const bool demoMode = true;` as the safe default, and do not expose a device to the public internet.

The app sends `X-Pairing-Token: <user-entered-token>` on every request. The token is configured by the device owner and must not be committed into source code. The base URL is the ESP8266 LAN address entered by the user, for example `http://192.168.1.50/`; all requests have a four-second bounded timeout and any non-2xx reply is an error. Example contract (JSON bodies use UTF-8):

```http
GET /api/status HTTP/1.1
Host: 192.168.1.50
Accept: application/json
X-Pairing-Token: <pairing-token>
```

```json
{"deviceId":"carebox-001","online":true,"firmware":"carebox-esp8266-0.1"}
```

```http
GET /api/events?after=2025-03-08T08%3A00%3A00.000Z HTTP/1.1
Host: 192.168.1.50
X-Pairing-Token: <pairing-token>
```

```json
{"events":[{"deviceId":"carebox-001","patientId":"patient-01","scheduleId":"morning-01","box":1,"event":"ACKNOWLEDGED","occurredAt":"2025-03-08T08:30:00Z"}]}
```

Events require `deviceId`, `patientId`, `scheduleId`, `box` (1–3), `event` and ISO-8601 `occurredAt`. Supported event names are `REMINDER_STARTED`, `ACKNOWLEDGED`, `MISSED`, `DEVICE_ONLINE` and `DEVICE_OFFLINE`. The client advances the timestamp cursor and deduplicates repeated records. Firmware should return events in ascending timestamp order and retain events long enough for a reconnecting client to retrieve them. Only a received `ACKNOWLEDGED` device event may be described as a dose acknowledgement; it confirms a device button acknowledgement, not medication ingestion.

```http
POST /api/schedules HTTP/1.1
Content-Type: application/json
X-Pairing-Token: <pairing-token>

{"schedules":[{"scheduleId":"morning-01","patientId":"patient-01","box":1,"hour":8,"minute":30,"enabled":true,"repeatDays":[1,2,3,4,5,6,7]}]}
```

```json
{"ok":true}
```

`repeatDays` uses ISO weekday integers: 1=Monday through 7=Sunday.

```http
POST /api/test/led
Content-Type: application/json
X-Pairing-Token: <pairing-token>

{"action":"test"}
```

```http
POST /api/test/buzzer HTTP/1.1
Content-Type: application/json
X-Pairing-Token: <pairing-token>

{"action":"test"}
```

```http
POST /api/reconnect HTTP/1.1
Content-Type: application/json
X-Pairing-Token: <pairing-token>

{"action":"reconnect"}
```

Each successful command returns HTTP 200 with `{"ok":true}` (or another 2xx response); invalid token returns 401, invalid input 400, unsupported command 404, and device/STM32 failures 503 with a JSON `{"error":"brief explanation"}` body. ESP8266 firmware is responsible for joining Wi-Fi, implementing the HTTP routes and token check, validating payloads, event buffering, and translating commands to the STM32 over UART. The STM32 remains responsible for real-time medication-box behavior and driving/reading its peripherals: reminder timing as designed, LEDs, buzzer, physical acknowledgement button and reporting resulting events over UART. Define a versioned UART frame format, checksums, message IDs, acknowledgements and timeout/retry behavior between the boards before firmware implementation; the Flutter contract alone does not define an already-existing UART protocol.

### Android local HTTP setup (after `flutter create`)

For this LAN-only HTTP prototype, edit `android/app/src/main/AndroidManifest.xml` after generating the Android project. Add `<uses-permission android:name="android.permission.INTERNET" />` as a direct child of `<manifest>`. For HTTP rather than HTTPS, set `android:usesCleartextTraffic="true"` on the existing `<application ...>` element (or use a narrowly scoped Android Network Security Config if available). Rebuild and install after changing the manifest. This permits unencrypted LAN traffic; a pairing token over plain HTTP is observable on that network, and a token is not transport encryption. HTTP plus a static token is prototype security only, not production security. Use authenticated TLS, device identity, rotation/revocation, replay protection, and a threat-reviewed protocol before production use. Do not port-forward the device or connect it directly to the internet.

### Same-Wi-Fi bring-up

1. Run `python export.py`, then create the Android shell with `flutter create . --platforms=android` and apply the manifest settings above.
2. Flash ESP8266 firmware implementing the routes above; connect the ESP8266 UART to the STM32 using compatible logic voltage levels, common ground, and the firmware's agreed baud/framing. Confirm STM32 firmware actually emits acknowledgement and status events.
3. Join the Android phone and ESP8266 to the same Wi-Fi network. Find the module's DHCP address from the router/serial logs; avoid guest Wi-Fi or client isolation.
4. In the app, choose **Local demo / Connect ESP8266 Wi-Fi prototype**, enter the module's LAN URL and configured pairing token, then connect. The screen first awaits `/api/status`; failed status or event requests remain visible as errors rather than being simulated as online. Keep the screen open to poll actual returned events. Leaving it or using Disconnect disposes the connection. The local demo remains separate.
5. Send schedules or invoke LED/buzzer/reconnect only with matching ESP8266 firmware installed. A successful HTTP response means the adapter accepted a request, not that physical behavior occurred. Verify hardware separately. Only received `ACKNOWLEDGED` and `MISSED` events matching an existing app schedule ID are written to history; unknown IDs are ignored. A received acknowledgement is a device event, not evidence of medication ingestion.

In VS Code, open `app/carebox_flutter`, run **Terminal → New Terminal**, then execute `python export.py`, `flutter create . --platforms=android`, `flutter pub get`, `flutter analyze`, and `flutter test`. Select a connected Android phone from the device picker and run `flutter run`; use the generated project as the workspace. These commands build and run the local demo; selecting a phone does not enable hardware connectivity. The device-service tests validate event parsing only; passing them does not prove that the hardware responds to requests. The Flutter demo test continues to cover exact-time schedule conflicts, reminder acknowledgement language, missed transitions, the rolling-window threshold and member-removal permission. The demo schedule, people, history and device state are sample data, not customer evidence or production telemetry.
