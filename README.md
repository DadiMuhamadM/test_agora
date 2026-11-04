# 🚐 Panduan Integrasi Agora (Chat & Call) - Shuttle Antar-Jemput

Repository ini berisi simulasi lengkap integrasi **Agora Chat SDK** (pesan teks & gambar) dan **Agora RTC Engine** (voice call & video call) untuk aplikasi **Shuttle Antar-Jemput** antara **Driver Armada** dan **Penumpang**.

---

## 📚 PANDUAN LENGKAP MIGRASI KE REAL PROJECT
Untuk memindahkan kodingan dari proyek dummy ini ke proyek asli Anda, silakan baca dokumentasi terpisah yang sudah disusun secara detail function-by-function:

1. 🚀 **[TUTORIAL_ROOM_CHAT_SUNJAYA.md](TUTORIAL_ROOM_CHAT_SUNJAYA.md)** *(Rekomendasi Utama)*:
   * **Tutorial copy-paste bertahap per potongan kecil** untuk memindahkan **Room Chat Penuh (Full Screen Page)** ke `sunjaya_mobile`.
   * Penjelasan fungsi tiap potongan: model pesan, state, listener Agora, kirim pesan, tombol voice/video call, dan pemanggilan via `Navigator.push`.

2. 💬 **[PANDUAN_CHAT.md](PANDUAN_CHAT.md)**:
   * Setup `agora_chat_sdk` & integrasi backend Laravel.
   * Alur login Google -> Register user ke Agora Chat -> Login SDK.
   * Bedah fungsi `init()`, `loginWithToken()`, `sendMessage()`, `onMessagesReceived()`, `loadMessages()`.
   * Cara kirim foto titik jemput / patokan penjemputan.

3. 📞 **[PANDUAN_CALL.md](PANDUAN_CALL.md)**:
   * Setup `agora_rtc_engine: ^6.6.4` & `permission_handler: 11.3.1`.
   * Fix native build Android (`libaosl.so` duplicate library).
   * Alur request Token RTC on-demand ke backend Laravel (`shuttle_booking_{id}`).
   * Call Signaling via Agora Chat (`action: "CALL_INVITE"`).
   * Bedah fungsi `createAgoraRtcEngine()`, `onJoinChannelSuccess`, `onUserJoined`, mute mic, speakerphone fix (mencegah error -3), switch camera, dan `release()`.
   * Widget UI Video Call (Floating PiP + Remote Fullscreen) & Voice Call.

---

## 📌 1. Konsep Utama: Agora Chat vs Agora RTC

Banyak developer pemula bingung membedakan antara fitur **Chat** dan fitur **Call**. Keduanya menggunakan modul dan teknologi yang berbeda dari Agora:

| Fitur | Package | Fungsi Utama | Kredensial yang Digunakan |
| :--- | :--- | :--- | :--- |
| **Chatting** | `agora_chat_sdk` | Mengirim pesan teks, status pesan, dan riwayat obrolan tersimpan. | **AppKey** + **Chat User Token** (per user ID). |
| **Voice & Video Call** | `agora_rtc_engine` | Streaming audio dan video *real-time* langsung antar-perangkat. | **App ID** + **Channel Name** + **RTC Token** (opsional pada mode testing). |

> [!IMPORTANT]
> **Panggilan Membutuhkan 3 Hal Utama:**
> 1. **`rtcAppId`**: App ID dari project Agora Anda.
> 2. **`channelId`**: Nama saluran yang **HARUS SAMA PERSIS** antara Driver dan Customer (contoh: `channelMetech`).
> 3. **`rtcToken`**: Token RTC khusus untuk channel tersebut (jika mode testing tanpa sertifikat, cukup string kosong `""`).

---

## 🛠️ 2. Struktur Konfigurasi (`AgoraConfig`)

Konfigurasi disimpan di dalam class `AgoraConfig` pada file [lib/main.dart](lib/main.dart):

```dart
class AgoraConfig {
  // 1. Kredensial Chat
  static const String appKey = "61200084352#200118764"; // Format: org_name#app_name

  // 2. Kredensial RTC (Voice & Video Call)
  static const String rtcAppId = "e36d7215a784494c817ed24da9b9c133";
  static const String channelId = "channelMetech"; // Saluran telepon bersama
  static const String rtcToken = ""; // Kosongkan jika mode testing, atau isi Token RTC dari Console

  // 3. Akun Penumpang
  static const String penumpangId = "dhadi-cust";
  static const String penumpangToken = "007eJxTYLi7aPs..."; // Chat User Token untuk dhadi-cust

  // 4. Akun Driver
  static const String driverId = "dhika-driver";
  static const String driverToken = "007eJxTYDj4j1N..."; // Chat User Token untuk dhika-driver
}
```

---

## 📖 3. Penjelasan Alur Kode Chat (`agora_chat_sdk`)

File utama obrolan berada di [lib/main.dart](lib/main.dart). Berikut tahapan logikanya:

### Tahap 1: Inisialisasi SDK
```dart
ChatOptions options = ChatOptions.withAppKey(
  AgoraConfig.appKey,
  autoLogin: false,
);
await ChatClient.getInstance.init(options);
await ChatClient.getInstance.startCallback();
```
* `ChatOptions.withAppKey(...)`: Menghubungkan SDK ke project Agora Chat Anda menggunakan `appKey`.
* `startCallback()`: Mengaktifkan jembatan callback native agar event listener dapat menerima data dari server.

### Tahap 2: Event Handler (Mendengarkan Pesan Masuk)
```dart
ChatClient.getInstance.chatManager.addEventHandler(
  "CHAT_LISTENER_UTAMA",
  ChatEventHandler(
    onMessagesReceived: (List<ChatMessage> messages) {
      for (var msg in messages) {
        // Logika penerimaan pesan & sinyal panggilan
      }
    },
  ),
);
```
* Listener ini bertindak seperti "telinga". Kapan pun ada pesan baru yang dikirim oleh lawan bicara, event `onMessagesReceived` akan otomatis dipicu secara *real-time*.

### Tahap 3: Login Pengguna
```dart
await ChatClient.getInstance.loginWithToken(userId, token);
```
* Mengautentikasi pengguna ke server Agora Chat.
* `userId` dan `token` harus berpasangan: token `dhadi-cust` hanya bisa digunakan untuk login `dhadi-cust`.

### Tahap 4: Mengirim Pesan Teks
```dart
final msg = ChatMessage.createTxtSendMessage(
  targetId: _targetUserId, // ID lawan bicara
  content: text,           // Teks obrolan
);
await ChatClient.getInstance.chatManager.sendMessage(msg);
```
* Pesan dibungkus sebagai `ChatMessage` dan dikirimkan ke `_targetUserId`. Begitu terkirim ke server, lawan bicara akan menerimanya melalui `onMessagesReceived`.

### Tahap 5: Memuat Riwayat Pesan (Chat History)
```dart
ChatConversation? conversation = await ChatClient.getInstance.chatManager
    .getConversation(_targetUserId);
if (conversation != null) {
  List<ChatMessage> list = await conversation.loadMessages(
    startMsgId: '',
    loadCount: 50,
    direction: ChatSearchDirection.Up,
  );
  // Tampilkan riwayat di UI
}
```
* Agora Chat otomatis menyimpan pesan di database SQLite internal perangkat. Saat pengguna membuka ruang chat atau berganti peran (*switch role*), `loadMessages()` mengambil percakapan lama sehingga riwayat tidak hilang.

---

## 📞 4. Penjelasan Alur Kode Panggilan (`agora_rtc_engine`)

Sistem panggilan dibagi menjadi dua proses: **Persinyalan Undangan (Signaling)** dan **Streaming Media (RTC)**.

### A. Persinyalan Panggilan Masuk (Call Signaling via Chat)
Agora RTC Engine adalah saluran transmisi suara/video, bukan sistem notifikasi dering. Oleh karena itu, kita memanfaatkan pesan Agora Chat untuk mengirimkan sinyal undangan:

```
[Penelepon: Driver]                                      [Penerima: Penumpang]
       |                                                           |
       |-- 1. Klik Tombol Telepon                                  |
       |-- 2. Kirim pesan chat dengan atribut 'CALL_INVITE' ------>|
       |-- 3. Masuk ke CallScreen ("Menghubungkan...")             |-- 4. Deteksi 'CALL_INVITE'
       |                                                           |-- 5. Muncul Dialog Pop-up
       |                                                           |      (Panggilan dari Driver)
       |                                                           |-- 6. Klik [TERIMA]
       |<========= 7. Keduanya Bergabung ke 'channelMetech' ======>|
       |                     (Audio & Video Aktif!)                |
```

Di sisi Penelepon ([lib/main.dart](lib/main.dart)):
```dart
final callMsg = ChatMessage.createTxtSendMessage(
  targetId: _targetUserId,
  content: "📞 Panggilan Suara Masuk...",
);
callMsg.attributes = {
  "action": "CALL_INVITE",
  "channelId": "channelMetech",
  "isVideo": false,
  "caller": _currentUserId,
};
await ChatClient.getInstance.chatManager.sendMessage(callMsg);
```

Di sisi Penerima ([lib/main.dart](lib/main.dart)):
```dart
final attrs = msg.attributes;
if (attrs != null && attrs["action"] == "CALL_INVITE") {
  _showIncomingCallDialog(
    caller: attrs["caller"],
    channelId: attrs["channelId"],
    isVideo: attrs["isVideo"],
  );
}
```

---

### B. Streaming Media di [lib/call_screen.dart](lib/call_screen.dart)

Saat panggilan diterima atau dimulai, aplikasi membuka `CallScreen`:

#### 1. Meminta Izin Runtime Android/iOS
```dart
await [Permission.microphone, Permission.camera].request();
```
* Android 6.0+ dan iOS mewajibkan izin mikrofon dan kamera diberikan secara eksplisit sebelum mengakses perangkat keras.

#### 2. Inisialisasi RTC Engine
```dart
_engine = createAgoraRtcEngine();
await _engine!.initialize(
  const RtcEngineContext(
    appId: AgoraConfig.rtcAppId,
    channelProfile: ChannelProfileType.channelProfileCommunication,
  ),
);
```
* `channelProfileCommunication`: Profil optimal untuk komunikasi dua arah (panggilan telepon/video call 1-on-1).

#### 3. Menangani Event Panggilan
```dart
_engine!.registerEventHandler(
  RtcEngineEventHandler(
    onJoinChannelSuccess: (connection, elapsed) {
      // Kita sendiri berhasil masuk ke channel
    },
    onUserJoined: (connection, remoteUid, elapsed) {
      // Lawan bicara mengangkat dan masuk ke channel
      // Timer panggilan mulai dihitung (00:01, 00:02, ...)
    },
    onUserOffline: (connection, remoteUid, reason) {
      // Lawan bicara menutup telepon -> otomatis keluar
    },
    onConnectionStateChanged: (connection, state, reason) {
      // Memantau status jaringan / jika ada masalah token
    },
  ),
);
```

#### 4. Bergabung ke Saluran (`joinChannel`)
```dart
await _engine!.joinChannel(
  token: AgoraConfig.rtcToken,
  channelId: widget.channelId, // "channelMetech"
  uid: 0,                      // 0 = Agora memberikan ID acak otomatis
  options: ChannelMediaOptions(
    clientRoleType: ClientRoleType.clientRoleBroadcaster,
    channelProfile: ChannelProfileType.channelProfileCommunication,
    publishCameraTrack: widget.isVideoCall,
    publishMicrophoneTrack: true,
  ),
);
```

#### 5. Menampilkan Video Lawan Bicara & Kamera Sendiri (Video Call)
* **Video Lawan Bicara (Remote)**:
  ```dart
  AgoraVideoView(
    controller: VideoViewController.remote(
      rtcEngine: _engine!,
      canvas: VideoCanvas(uid: _remoteUid!),
      connection: RtcConnection(channelId: widget.channelId),
    ),
  )
  ```
* **Kamera Depan Kita Sendiri (Floating PiP Pojok Kanan Atas)**:
  ```dart
  AgoraVideoView(
    controller: VideoViewController(
      rtcEngine: _engine!,
      canvas: const VideoCanvas(uid: 0), // uid 0 = kamera lokal
    ),
  )
  ```

---

## ⚠️ 5. Catatan Teknis & Troubleshooting Android

### 1. Izin di `AndroidManifest.xml`
Pastikan izin berikut terdaftar di `android/app/src/main/AndroidManifest.xml`:
```xml
<uses-permission android:name="android.permission.INTERNET"/>
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE"/>
<uses-permission android:name="android.permission.RECORD_AUDIO"/>
<uses-permission android:name="android.permission.CAMERA"/>
<uses-permission android:name="android.permission.MODIFY_AUDIO_SETTINGS"/>
<uses-permission android:name="android.permission.ACCESS_WIFI_STATE"/>
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT"/>
```

### 2. Konflik File Native `libaosl.so`
Karena `agora_chat_sdk` dan `agora_rtc_engine` sama-sama menyertakan file native C++ `libaosl.so`, Gradle Android memerlukan aturan `pickFirsts` di `android/app/build.gradle.kts`:
```kotlin
android {
    packaging {
        jniLibs {
            pickFirsts += listOf(
                "lib/x86/libaosl.so",
                "lib/x86_64/libaosl.so",
                "lib/armeabi-v7a/libaosl.so",
                "lib/arm64-v8a/libaosl.so"
            )
        }
    }
}
```

### 3. Error `-3` (`ERR_NOT_READY`) pada Speakerphone
Fungsi `setEnableSpeakerphone(true)` tidak boleh dipanggil sebelum `joinChannel` berhasil. Sebelum join, gunakan `setDefaultAudioRouteToSpeakerphone(true)`.

---

## 🧪 6. Langkah-Langkah Pengujian (Testing)

### Cara Menguji Obrolan (Chat)
1. Buka aplikasi di **Device 1**, login sebagai **PENUMPANG (`dhadi-cust`)**.
2. Buka aplikasi di **Device 2**, login sebagai **DRIVER (`dhika-driver`)**.
3. Ketik pesan di salah satu perangkat $\rightarrow$ pesan langsung diterima di perangkat lain.

### Cara Menguji Panggilan Suara & Video (Call & VC)
1. Pastikan kedua perangkat login di akun masing-masing.
2. Dari sisi **Driver**, tekan ikon 📞 (Panggilan Suara) atau 📹 (Video Call) di AppBar.
3. Di layar **Penumpang**, otomatis akan muncul **Pop-Up Dialog Panggilan Masuk**:
   * Nama Penelepon: `dhika-driver`
   * Tekan tombol hijau **"Terima"**.
4. Kedua perangkat otomatis terhubung ke channel `channelMetech`, timer obrolan berjalan, dan suara/video langsung streaming dua arah.
