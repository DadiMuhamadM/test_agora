# 📞 Panduan Lengkap Implementasi AGORA CALL (Voice & Video) di Proyek Shuttle Antar-Jemput

Dokumen ini adalah panduan langkah demi langkah untuk memindahkan fitur **Panggilan Suara (Voice Call)** dan **Panggilan Video (Video Call)** dari proyek dummy (`test_agora`) ke dalam **Real Project Shuttle Antar-Jemput** Anda (Flutter + Laravel).

---

## 📌 DAFTAR ISI
1. [Arsitektur Panggilan di Aplikasi Shuttle](#1-arsitektur-panggilan-di-aplikasi-shuttle)
2. [Langkah 1: Setup Dependensi & Konfigurasi Native Android](#langkah-1-setup-dependensi--konfigurasi-native-android)
3. [Langkah 2: Alur Backend Laravel untuk Panggilan RTC](#langkah-2-alur-backend-laravel-untuk-panggilan-rtc)
4. [Langkah 3: Alur Sinyal Panggilan (Call Signaling via Agora Chat)](#langkah-3-alur-sinyal-panggilan-call-signaling-via-agora-chat)
5. [Langkah 4: Bedah Lengkap Kode CallScreen (Function by Function)](#langkah-4-bedah-lengkap-kode-callscreen-function-by-function)
6. [Langkah 5: Solusi Error Nyata yang Pernah Terjadi (Wajib Diperhatikan)](#langkah-5-solusi-error-nyata-yang-pernah-terjadi-wajib-diperhatikan)
7. [Langkah 6: Cara Menghubungkan ke UI Custom Shuttle Anda](#langkah-6-cara-menghubungkan-ke-ui-custom-shuttle-anda)

---

## 1. Arsitektur Panggilan di Aplikasi Shuttle

Dalam aplikasi shuttle antar-jemput, panggilan telepon (suara/video) dibutuhkan pada momen-momen kritis penjemputan:
* **Voice Call:** Driver menghubungi penumpang ketika armada sudah mendekati titik penjemputan (*"Halo Pak, saya di depan gerbang perumahan"*).
* **Video Call:** Penumpang memperlihatkan patokan lokasi fisik penjemputan yang membingungkan atau driver memperlihatkan posisi armada shuttle miliknya.

```
+-----------------------------------------------------------------------------------+
| ALUR PANGGILAN SHUTTLE (DRIVER <-> PENUMPANG)                                     |
+-----------------------------------------------------------------------------------+

[PENUMPANG]                                                                [DRIVER]
     |                                                                         |
     |-- 1. Tekan tombol Telepon di halaman Shuttle / Chat                     |
     |-- 2. Request Token RTC ke Backend Laravel                               |
     |      POST /api/shuttle/call/token { booking_id: 45 }                    |
     |      (Mendapat channelId: "shuttle_booking_45" & rtcToken)              |
     |                                                                         |
     |-- 3. Kirim Sinyal via Agora Chat:                                       |
     |      ChatMessage(attributes: { action: "CALL_INVITE", channelId: ...})->|
     |                                                                         |
     |-- 4. Buka Layar CallScreen & joinChannel()                              |-- 4. Muncul Pop-up Dialog:
     |                                                                         |      "Panggilan Masuk dari Penumpang"
     |                                                                         |      [Tolak]  /  [Terima]
     |                                                                         |
     |                                                                         |-- 5. Driver klik "Terima":
     |                                                                         |      Buka Layar CallScreen & joinChannel()
     |                                                                         |
     |<============== 6. STREAM AUDIO / VIDEO AKTIF (AGORA RTC) ==============>|
```

---

## Langkah 1: Setup Dependensi & Konfigurasi Native Android

### 1. File `pubspec.yaml`
Gunakan versi package yang sudah teruji stabil dan tidak menimbulkan konflik Kotlin compiler:

```yaml
dependencies:
  flutter:
    sdk: flutter
  agora_rtc_engine: ^6.6.4     # SDK Resmi Agora RTC (Voice & Video)
  permission_handler: 11.3.1   # PENTING: Gunakan 11.3.1 (jangan 13.x/14.x agar tidak konflik Gradle)
  agora_chat_sdk: ^1.4.0+1     # Untuk sinyal notifikasi panggilan
```

Jalankan perintah di terminal:
```bash
flutter pub get
```

---

### 2. Fix Konflik Native Library di `android/app/build.gradle.kts`
> [!IMPORTANT]
> Saat Anda menggabungkan `agora_chat_sdk` dan `agora_rtc_engine`, kedua library native membawa file binary C++ yang sama bernama `libaosl.so`. Tanpa konfigurasi ini, Android Gradle akan gagal build (`duplicate files during packaging of APK`).

Buka file `android/app/build.gradle.kts` dan tambahkan blok `packaging` di dalam blok `android { ... }`:

```kotlin
android {
    ...
    // TAMBAHKAN BAGIAN INI:
    packaging {
        jniLibs {
            pickFirsts += listOf(
                "**/libaosl.so"
            )
        }
    }
}
```

---

### 3. Fix Error R8 `minifyReleaseWithR8` saat Build APK Release
Saat melakukan `flutter build apk --release`, compiler R8 akan memeriksa kelas native Agora. Agar tidak gagal compile (*Compilation failed to complete*):

1. **Nonaktifkan minify di `android/app/build.gradle.kts`**:
```kotlin
buildTypes {
    release {
        signingConfig = signingConfigs.getByName("debug")
        isMinifyEnabled = false
        isShrinkResources = false
        proguardFiles(
            getDefaultProguardFile("proguard-android-optimize.txt"),
            "proguard-rules.pro"
        )
    }
}
```
2. **Buat file `android/app/proguard-rules.pro`** dan isi dengan:
```proguard
-keep class io.agora.** { *; }
-dontwarn io.agora.**
-keep class com.hyphenate.** { *; }
-dontwarn com.hyphenate.**
-keepclassmembers class * { native <methods>; }
-dontwarn **
```
3. **Tambahkan di `android/gradle.properties`**:
```properties
android.enableR8.fullMode=false
```

---

### 3. File `android/app/src/main/AndroidManifest.xml`
Tambahkan perizinan mikrofon, kamera, dan audio di dalam tag `<manifest ...>`:

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">

    <!-- Izin untuk Panggilan Suara & Video Agora RTC -->
    <uses-permission android:name="android.permission.INTERNET" />
    <uses-permission android:name="android.permission.RECORD_AUDIO" />
    <uses-permission android:name="android.permission.CAMERA" />
    <uses-permission android:name="android.permission.MODIFY_AUDIO_SETTINGS" />
    <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
    <uses-permission android:name="android.permission.ACCESS_WIFI_STATE" />
    <uses-permission android:name="android.permission.BLUETOOTH" />
    <uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />

    <application ...>
        ...
    </application>
</manifest>
```

---

## Langkah 2: Alur Backend Laravel untuk Panggilan RTC

### 1. Kapan Token RTC Harus Dibuat?
* **JANGAN** membuat token RTC saat login aplikasi.
* **JANGAN** membuat token RTC saat membuka halaman daftar riwayat booking.
* **BUATLAH SECARA ON-DEMAND:** Yaitu saat salah satu pihak (driver atau penumpang) **menekan tombol telepon**.

### 2. Aturan Penamaan Channel ID di Aplikasi Shuttle
Gunakan format channel ID berbasis **ID Booking Penjemputan**, contoh:
```
shuttle_booking_{booking_id}
Contoh: "shuttle_booking_105"
```
**Mengapa?**
1. Armada shuttle biasanya membawa beberapa penumpang sekaligus (misal: 6 orang penumpang).
2. Jika driver menelepon Penumpang A, channelnya harus `shuttle_booking_105`. Penumpang B dan C di mobil yang sama tidak boleh mendengar obrolan tersebut.
3. Setelah penjemputan selesai, channel tersebut ditinggalkan dan tidak aktif lagi.

### 3. Contoh Controller Laravel (`AgoraRtcController.php`)
```php
namespace App\Http\Controllers\Api;

use App\Http\Controllers\Controller;
use Illuminate\Http\Request;
use App\Services\AgoraRtcTokenBuilder; // Menggunakan package agora-token-builder

class AgoraRtcController extends Controller
{
    public function generateRtcToken(Request $request)
    {
        $request->validate([
            'booking_id' => 'required',
            'role'       => 'nullable|string', // 'publisher'
        ]);

        $appId = config('services.agora.rtc_app_id');
        $appCertificate = config('services.agora.rtc_app_certificate');
        $channelName = "shuttle_booking_" . $request->booking_id;
        $uid = 0; // Uid 0 mengizinkan Agora mengalokasikan integer UID secara otomatis

        // Token berlaku selama 1 jam (3600 detik)
        $expireTimeInSeconds = 3600;
        $currentTimestamp = (new \DateTime("now", new \DateTimeZone('UTC')))->getTimestamp();
        $privilegeExpiredTs = $currentTimestamp + $expireTimeInSeconds;

        $token = AgoraRtcTokenBuilder::buildTokenWithUid(
            $appId,
            $appCertificate,
            $channelName,
            $uid,
            AgoraRtcTokenBuilder::RolePublisher,
            $privilegeExpiredTs
        );

        return response()->json([
            'status' => true,
            'data'   => [
                'appId'       => $appId,
                'channelId'   => $channelName,
                'rtcToken'    => $token,
                'uid'         => $uid,
            ]
        ]);
    }
}
```

---

## Langkah 3: Alur Sinyal Panggilan (Call Signaling via Agora Chat)

Karena Agora RTC murni bertugas menyalurkan suara dan gambar (tidak punya fitur *ringing* bawaan), kita menggunakan **Agora Chat** untuk mengirimkan sinyal "Panggilan Masuk" ke lawan bicara.

### Sisi Penelepon (Memulai Panggilan)
```dart
Future<void> startShuttleCall({
  required BuildContext context,
  required String targetUserId,     // Misal: "driver_5" atau "cust_12"
  required String bookingId,        // Misal: "105"
  required bool isVideo,
}) async {
  // 1. Ambil Token RTC & Channel ID dari API Laravel
  final callData = await CallApiService.fetchRtcToken(bookingId: bookingId);
  final channelId = callData['channelId']; // "shuttle_booking_105"
  final rtcToken = callData['rtcToken'];

  // 2. Kirim pesan sinyal panggilan ke lawan bicara via Agora Chat
  final callSignalMsg = ChatMessage.createTxtSendMessage(
    targetId: targetUserId,
    content: isVideo ? "📹 Panggilan Video Masuk..." : "📞 Panggilan Suara Masuk...",
  );
  
  // SELIPKAN METADATA PANGGILAN DI DALAM ATTRIBUTES
  callSignalMsg.attributes = {
    "action": "CALL_INVITE",
    "channelId": channelId,
    "rtcToken": rtcToken,
    "isVideo": isVideo,
    "callerName": "Driver Antar-Jemput (Budi)",
  };

  await ChatClient.getInstance.chatManager.sendMessage(callSignalMsg);

  // 3. Penelepon langsung masuk ke CallScreen
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (context) => CallScreen(
        channelId: channelId,
        rtcToken: rtcToken,
        isVideoCall: isVideo,
        targetName: "Penumpang (Siti)",
      ),
    ),
  );
}
```

### Sisi Penerima (Mendeteksi Panggilan Masuk di Listener Chat)
Di listener Agora Chat (`ChatEventHandler.onMessagesReceived`):
```dart
@override
void onMessagesReceived(List<ChatMessage> messages) {
  for (var msg in messages) {
    // Periksa apakah pesan ini adalah sinyal panggilan
    if (msg.attributes != null && msg.attributes!["action"] == "CALL_INVITE") {
      final channelId = msg.attributes!["channelId"] as String;
      final rtcToken = msg.attributes!["rtcToken"] as String? ?? "";
      final isVideo = msg.attributes!["isVideo"] as bool? ?? false;
      final callerName = msg.attributes!["callerName"] as String? ?? "Driver/Penumpang";

      // Tampilkan Dialog Pop-up Panggilan Masuk di layar
      _showIncomingCallDialog(
        callerName: callerName,
        channelId: channelId,
        rtcToken: rtcToken,
        isVideo: isVideo,
      );
      break;
    }
  }
}
```

---

## Langkah 4: Bedah Lengkap Kode CallScreen (Function by Function)

File `call_screen.dart` adalah inti dari pemrosesan audio dan video. Berikut bedah fungsi dan alur logikanya:

### 1. Inisialisasi Engine & Izin Perangkat (`_initAgoraRtc`)
```dart
Future<void> _initAgoraRtc() async {
  // A. Minta izin Mikrofon dan Kamera (Wajib sebelum createAgoraRtcEngine)
  if (widget.isVideoCall) {
    final statuses = await [Permission.microphone, Permission.camera].request();
    if (statuses[Permission.microphone] != PermissionStatus.granted ||
        statuses[Permission.camera] != PermissionStatus.granted) {
      _showErrorAndExit("Izin kamera dan mikrofon diperlukan.");
      return;
    }
  } else {
    final status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      _showErrorAndExit("Izin mikrofon diperlukan.");
      return;
    }
  }

  // B. Buat objek RTC Engine
  _engine = createAgoraRtcEngine();
  await _engine!.initialize(
    const RtcEngineContext(
      appId: "APP_ID_RTC_ANDA",
      channelProfile: ChannelProfileType.channelProfileCommunication, // Mode komunikasi 2 arah
    ),
  );

  // C. Daftarkan Event Handler
  _registerEngineEvents();

  // D. Aktifkan Video atau Audio sesuai tipe panggilan
  if (widget.isVideoCall) {
    await _engine!.enableVideo();
    await _engine!.startPreview(); // Menyalakan kamera lokal untuk preview
  } else {
    await _engine!.enableAudio();
  }

  // E. Set rute audio default ke Speakerphone (Mencegah error -3 ERR_NOT_READY)
  await _engine!.setDefaultAudioRouteToSpeakerphone(true);

  // F. Masuk ke Channel
  await _engine!.joinChannel(
    token: widget.rtcToken, // Jika App Certificate disable, isi string kosong ""
    channelId: widget.channelId,
    uid: 0, // Agora akan mengalokasikan integer UID otomatis
    options: ChannelMediaOptions(
      clientRoleType: ClientRoleType.clientRoleBroadcaster,
      channelProfile: ChannelProfileType.channelProfileCommunication,
      publishCameraTrack: widget.isVideoCall,
      publishMicrophoneTrack: true,
    ),
  );
}
```

---

### 2. Event Handler RTC (`_registerEngineEvents`)
Fungsi-fungsi callback ini dipanggil otomatis oleh SDK Agora saat kondisi jaringan atau partisipan berubah:

| Callback Event | Kapan Dipanggil? | Logika Tindakan yang Dilakukan |
| :--- | :--- | :--- |
| `onJoinChannelSuccess` | Saat HP kita berhasil masuk ke room channel. | Ubah state `_localUserJoined = true`, dan set speakerphone. |
| `onUserJoined` | Saat lawan bicara (driver/penumpang) ikut masuk ke room. | Simpan `_remoteUid = remoteUid`, mulai timer durasi panggilan (`_startCallTimer()`). Panggilan resmi tersambung! |
| `onUserOffline` | Saat lawan bicara keluar dari room / menutup aplikasi. | Hapus `_remoteUid = null`, hentikan panggilan, dan tutup layar dengan pop-up. |
| `onConnectionStateChanged` | Saat status koneksi berubah (Connecting, Connected, Reconnecting, Failed). | Menangkap error krusial seperti: `connectionChangedInvalidToken` atau `connectionChangedTokenExpired`. |

Kodingannya:
```dart
void _registerEngineEvents() {
  _engine!.registerEventHandler(
    RtcEngineEventHandler(
      onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
        setState(() => _localUserJoined = true);
        try {
          _engine?.setEnableSpeakerphone(_isSpeaker);
        } catch (_) {}
      },
      onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
        setState(() => _remoteUid = remoteUid);
        _startCallTimer(); // Mulai hitung detik (00:01, 00:02, ...)
      },
      onUserOffline: (RtcConnection connection, int remoteUid, UserOfflineReasonType reason) {
        setState(() => _remoteUid = null);
        _showExitDialog("Lawan bicara telah mengakhiri panggilan.");
      },
      onConnectionStateChanged: (RtcConnection connection, ConnectionStateType state, ConnectionChangedReasonType reason) {
        if (reason == ConnectionChangedReasonType.connectionChangedInvalidToken) {
          _showErrorAndExit("Token RTC tidak valid! Cek App ID & Token di Laravel.");
        } else if (reason == ConnectionChangedReasonType.connectionChangedTokenExpired) {
          _showErrorAndExit("Token RTC kedaluwarsa.");
        }
      },
    ),
  );
}
```

---

### 3. Kontrol Panggilan (Mute, Speaker, Kamera, End Call)
Fungsi-fungsi ini dihubungkan ke tombol aksi di bagian bawah layar:

```dart
// 1. Mute / Unmute Mikrofon Kita
Future<void> _toggleMute() async {
  setState(() => _isMuted = !_isMuted);
  await _engine?.muteLocalAudioStream(_isMuted);
}

// 2. Ganti Output Suara (Speakerphone HP vs Earpiece Telinga)
Future<void> _toggleSpeaker() async {
  setState(() => _isSpeaker = !_isSpeaker);
  await _engine?.setEnableSpeakerphone(_isSpeaker);
}

// 3. Matikan / Nyalakan Kamera Video Kita Sendiri
Future<void> _toggleVideo() async {
  setState(() => _isVideoDisabled = !_isVideoDisabled);
  await _engine?.muteLocalVideoStream(_isVideoDisabled);
}

// 4. Balik Kamera Depan <-> Kamera Belakang
Future<void> _switchCamera() async {
  await _engine?.switchCamera();
}

// 5. Mengakhiri Panggilan & Membersihkan Memori (Wajib!)
Future<void> _endCall() async {
  _timer?.cancel();
  try {
    await _engine?.leaveChannel(); // Keluar dari channel Agora
    await _engine?.release();      // Matikan hardware kamera & mic
  } catch (e) {
    debugPrint("Error saat release RTC: $e");
  }
  if (mounted) {
    Navigator.of(context).pop();
  }
}
```

---

### 4. Menampilkan Video Lawan Bicara & Kamera Lokal (Widget UI)

Untuk merender video, gunakan widget resmi `AgoraVideoView`:

#### A. Video Lawan Bicara (Layar Penuh / Remote)
```dart
AgoraVideoView(
  controller: VideoViewController.remote(
    rtcEngine: _engine!,
    canvas: VideoCanvas(uid: _remoteUid!), // Menggunakan remoteUid dari callback onUserJoined
    connection: RtcConnection(channelId: widget.channelId),
  ),
)
```

#### B. Kamera Kita Sendiri (Kotak Kecil Floating / Local)
```dart
Positioned(
  top: 20,
  right: 20,
  width: 110,
  height: 150,
  child: ClipRRect(
    borderRadius: BorderRadius.circular(12),
    child: AgoraVideoView(
      controller: VideoViewController(
        rtcEngine: _engine!,
        canvas: const VideoCanvas(uid: 0), // uid: 0 selalu merujuk ke kamera lokal kita sendiri
      ),
    ),
  ),
)
```

---

## Langkah 5: Solusi Error Nyata yang Pernah Terjadi (Wajib Diperhatikan)

Di masa uji coba, ada beberapa kendala teknis yang umum dihadapi developer. Simpan solusi ini sebagai referensi:

### 1. Error: Layar Panggilan "Menghubungkan terus..." (Stuck di Connecting)
* **Penyebab:** Anda memasukkan Token **Chat** ke dalam parameter `joinChannel()` milik **RTC Engine**.
* **Penjelasan:** Agora membedakan Service Type Token:
  * Service Type 5 = **Chat Token**
  * Service Type 1 = **RTC Token**
* **Solusi:** Pastikan token yang disuplai ke `CallScreen` dihasilkan oleh generator RTC Token, bukan Chat Token. Jika pada Agora Console opsi *App Certificate* belum diaktifkan (Testing Mode), kirim string kosong `""` ke parameter token.

---

### 2. Error: `AgoraRtcException(-3, null)` saat Inisialisasi
* **Penyebab:** Memanggil `_engine.setEnableSpeakerphone(true)` *sebelum* `joinChannel()` berhasil diselesaikan. Kode `-3` artinya `ERR_NOT_READY`.
* **Solusi:**
  1. Sebelum `joinChannel()`, panggil:
     ```dart
     await _engine!.setDefaultAudioRouteToSpeakerphone(true);
     ```
  2. Panggilan `_engine.setEnableSpeakerphone(...)` hanya boleh dijalankan di dalam callback `onJoinChannelSuccess` dan dibungkus `try-catch`.

---

### 3. Error Build Android: `duplicate files during packaging of APK (libaosl.so)`
* **Penyebab:** `agora_chat_sdk` dan `agora_rtc_engine` keduanya menyertakan file binary native `libaosl.so`.
* **Solusi:** Tambahkan `pickFirsts += listOf("**/libaosl.so")` pada `android/app/build.gradle.kts` (seperti yang dijelaskan pada Langkah 1).

---

## Langkah 6: Cara Menghubungkan ke UI Custom Shuttle Anda

Anda sudah membuat UI untuk Shuttle Anda. Berikut cara menyambungkan tombol-tombol pada UI Anda:

### 1. Di Halaman Room Chat (AppBar Action)
Tambahkan dua tombol di kanan atas AppBar chat room Anda:
```dart
AppBar(
  title: Text("Driver Antar-Jemput"),
  actions: [
    // Tombol Voice Call
    IconButton(
      icon: const Icon(Icons.phone),
      onPressed: () {
        startShuttleCall(
          context: context,
          targetUserId: widget.targetDriverId,
          bookingId: widget.bookingId,
          isVideo: false,
        );
      },
    ),
    // Tombol Video Call
    IconButton(
      icon: const Icon(Icons.videocam),
      onPressed: () {
        startShuttleCall(
          context: context,
          targetUserId: widget.targetDriverId,
          bookingId: widget.bookingId,
          isVideo: true,
        );
      },
    ),
  ],
)
```

### 2. Di Kartu Booking Driver (List Penumpang yang Dijemput)
Driver memiliki daftar penumpang yang harus dijemput satu per satu. Pasang tombol telepon langsung di tiap kartu penumpang:
```dart
ListTile(
  leading: CircleAvatar(child: Icon(Icons.person)),
  title: Text(penumpang.nama),
  subtitle: Text("Titik Jemput: ${penumpang.alamatJemput}"),
  trailing: IconButton(
    icon: const Icon(Icons.phone, color: Colors.green),
    onPressed: () {
      startShuttleCall(
        context: context,
        targetUserId: penumpang.userId,
        bookingId: penumpang.bookingId,
        isVideo: false,
      );
    },
  ),
)
```

Dengan arsitektur ini, panggilan suara dan video akan berjalan privat, jernih, dan aman sesuai tiket penjemputan armada shuttle Anda! 🚀
