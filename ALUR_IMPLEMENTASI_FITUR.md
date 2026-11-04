# 🚀 Alur Lengkap Implementasi & Development Fitur Shuttle Chat

Dokumen ini memuat **alur pengembangan (development workflow), arsitektur kerja, dan langkah implementasi step-by-step** dari seluruh fitur utama yang ada di project ini.

Gunakan panduan ini sebagai acuan teknis saat Anda ingin memindahkan (*porting*) fitur-fitur ini ke aplikasi utama (**`sunjaya_mobile`**).

---

## 📑 Daftar Isi
1. [Prasyarat & Konfigurasi Dasar](#1-prasyarat--konfigurasi-dasar)
2. [Alur Fitur 1: Panggilan Suara & Video Call (Voice & Video)](#2-alur-fitur-1-panggilan-suara--video-call)
3. [Alur Fitur 2: Chat Teks Real-Time](#3-alur-fitur-2-chat-teks-real-time)
4. [Alur Fitur 3: Pengiriman Gambar / Foto (Media Upload)](#4-alur-fitur-3-pengiriman-gambar--foto)
5. [Alur Fitur 4: Status Pesan & Ceklis Biru WhatsApp (Read Receipts)](#5-alur-fitur-4-status-pesan--ceklis-biru-whatsapp)
6. [Alur Fitur 5: Notifikasi Banner Mengambang (In-App Banner)](#6-alur-fitur-5-notifikasi-banner-mengambang)
7. [Alur Fitur 6: Helpdesk CS Dinamis & Hapus Riwayat Chat](#7-alur-fitur-6-helpdesk-cs-dinamis--hapus-riwayat-chat)

---

## 1. Prasyarat & Konfigurasi Dasar

Sebelum mengembangkan fitur, siapkan dependencies dan izin perangkat:

### Dependencies (`pubspec.yaml`):
```yaml
dependencies:
  flutter:
    sdk: flutter
  agora_chat_sdk: ^1.4.0+1   # Untuk fitur Chat, Media, Signaling, dan Notif
  agora_rtc_engine: ^6.3.2   # Untuk streaming audio & video call
  image_picker: ^1.1.2       # Untuk memilih foto dari galeri/kamera
  permission_handler: ^11.3.1# Untuk izin akses Mikrofon & Kamera
```

### Izin Perangkat (Permissions):
* **Android (`AndroidManifest.xml`)**:
  * `android.permission.INTERNET`
  * `android.permission.RECORD_AUDIO` (Mikrofon)
  * `android.permission.CAMERA` (Kamera)
  * `android.permission.READ_EXTERNAL_STORAGE` / `READ_MEDIA_IMAGES` (Galeri)
* **iOS (`Info.plist`)**:
  * `NSMicrophoneUsageDescription`
  * `NSCameraUsageDescription`
  * `NSPhotoLibraryUsageDescription`

---

## 2. Alur Fitur 1: Panggilan Suara & Video Call

### 💡 Konsep Arsitektur:
Agora RTC **tidak memiliki sistem dering**. Oleh karena itu, kita menggabungkan **dua engine**:
1. **Agora Chat SDK (Signaling)**: Mengirim sinyal dering seperti *"Hei, angkat telepon, ini nama channel RTC-nya!"*.
2. **Agora RTC Engine**: Menangani streaming suara & video setelah tombol "Terima" ditekan.

### 🔄 Diagram Alur Kerja:
```
[User A (Penelepon)]                                [User B (Penerima)]
        │                                                    │
 1. Klik Icon Telepon                                        │
        │                                                    │
 2. Kirim pesan Agora Chat                                   │
    attributes: {"action": "CALL_INVITE",                    │
                 "channelId": "demo",                        │
                 "callTime": timestamp}                      │
        ├───────────────────────────────────────────────────►│ 3. onMessagesReceived mendeteksi
        │                                                    │    action == "CALL_INVITE"
 4. Buka Layar CallScreen                                    │
    joinChannel("demo")                                      │ 4. Cek usia pesan (< 35 detik)
        │                                                    │
        │                                                    │ 5. Muncul Pop-up Dialog
        │                                                    │    Tolak / Terima
        │                                                    │       │
        │                                     (Jika Terima) ─┴───────┤
        │                                                            ▼
        │                                                    6. Buka Layar CallScreen
        │                                                       joinChannel("demo")
        ◄────────────────────────────────────────────────────►
                 7. TERKONEKSI (Suara & Video Live)
```

### 🛠️ Langkah-Langkah Development:
1. **Langkah 1 (Penelepon - Kirim Sinyal)**:
   * Buat pesan teks biasa via `ChatMessage.createTxtSendMessage()`.
   * Beri atribut: `{"action": "CALL_INVITE", "channelId": channelId, "isVideo": isVideo, "callTime": DateTime.now().millisecondsSinceEpoch}`.
   * Panggil `sendMessage()`, lalu langsung `Navigator.push` ke `CallScreen`.
2. **Langkah 2 (Penerima - Tangkap Sinyal)**:
   * Di listener `onMessagesReceived`, periksa apakah `msg.attributes?["action"] == "CALL_INVITE"`.
   * **Validasi Anti-Bug**: Cek selisih waktu (`callTime`). Jika > 35 detik, abaikan (*missed call* lama).
   * Panggil `continue;` agar tidak diproses sebagai chat biasa.
3. **Langkah 3 (Dialog Pop-up & Connect RTC)**:
   * Tampilkan `_showIncomingCallDialog()`.
   * Jika user klik **Tolak** → tutup dialog (`Navigator.pop`).
   * Jika user klik **Terima** → arahkan ke `CallScreen` dengan `channelId` yang sama.
   * Di `CallScreen`, inisialisasi `RtcEngine`, pasang video canvas, dan panggil `joinChannel()`.

---

## 3. Alur Fitur 2: Chat Teks Real-Time

### 💡 Konsep Arsitektur:
Komunikasi peer-to-peer 1-on-1 (*Single Chat*) yang tersimpan di server Agora dan database lokal SQLite HP.

### 🛠️ Langkah-Langkah Development:
1. **Langkah 1 (Inisialisasi & Login)**:
   * Jalankan `ChatClient.getInstance.init(ChatOptions.withAppKey(appKey))`.
   * Login user menggunakan ID dan Token: `ChatClient.getInstance.loginWithToken(userId, token)`.
2. **Langkah 2 (Memuat Riwayat Chat)**:
   * Ambil riwayat dari lokal/server:
     ```dart
     final conv = await ChatClient.getInstance.chatManager.getConversation(targetUserId);
     final messages = await conv.loadMessages(startMsgId: '', count: 50);
     ```
   * Urutkan pesan dari yang terlama ke terbaru berdasarkan `serverTime`.
3. **Langkah 3 (Mengirim Pesan)**:
   * Buat pesan teks: `final msg = ChatMessage.createTxtSendMessage(targetId: targetId, content: text);`.
   * Kirim ke Agora: `await ChatClient.getInstance.chatManager.sendMessage(msg);`.
   * Tambahkan langsung ke list UI (*Optimistic UI*) dan scroll ke paling bawah.
4. **Langkah 4 (Menerima Pesan Real-time)**:
   * Pasang listener `ChatEventHandler(onMessagesReceived: (messages) { ... })`.
   * Cek apakah `msg.from == targetUserId`. Jika cocok, masukkan ke list UI.

---

## 4. Alur Fitur 3: Pengiriman Gambar / Foto

### 💡 Konsep Arsitektur:
Aplikasi tidak perlu membuat server backend atau AWS S3 sendiri untuk file storage. Agora Chat SDK sudah menyediakan **Agora Cloud CDN** terintegrasi.

```
[Pilih Foto] ──► [Kompres 75%] ──► [Kirim via Agora] ──► [Agora CDN] ──► [Penerima Download]
```

### 🛠️ Langkah-Langkah Development:
1. **Langkah 1 (Ambil & Kompres Foto)**:
   * Gunakan package `image_picker`.
   * Terapkan `imageQuality: 75`, `maxWidth: 1280` agar foto jernih namun ukuran file tetap kecil (cepat terkirim & hemat kuota).
2. **Langkah 2 (Kirim via Agora Media)**:
   * Gunakan method bawaan:
     ```dart
     final msg = ChatMessage.createImageSendMessage(
       targetId: targetUserId,
       filePath: pickedFile.path,
       displayName: pickedFile.name,
     );
     await ChatClient.getInstance.chatManager.sendMessage(msg);
     ```
   * Agora otomatis meng-upload gambar ke cloud CDN dan memberikan link `remotePath` serta `thumbnailRemotePath`.
3. **Langkah 3 (Menampilkan di Sisi Penerima)**:
   * **Optimasi Kecepatan**: Cek apakah SDK Agora sudah mengunduh file ke penyimpanan lokal HP (`body.localPath` atau `body.thumbnailLocalPath`).
   * Jika ada di lokal: Render instan pakai `Image.file()`.
   * Jika belum ada di lokal: Render via internet pakai `Image.network(body.remotePath)`.

---

## 5. Alur Fitur 4: Status Pesan & Ceklis Biru WhatsApp

### 💡 Konsep Arsitektur:
Memanfaatkan protokol **Read Receipt** bawaan Agora Chat:
* **Ceklis 1 Abu-abu**: Pesan sukses dikirim ke server Agora.
* **Ceklis 2 Abu-abu**: Pesan sukses sampai di HP penerima (*Delivered*).
* **Ceklis 2 Biru (`#00E5FF`)**: Pesan telah dibuka dan dibaca oleh lawan bicara (*Read*).

### 🛠️ Langkah-Langkah Development:
1. **Langkah 1 (Aktifkan Opsi Receipt di SDK)**:
   * Saat inisialisasi `ChatOptions`, set `requireAck: true` dan `requireDeliveryAck: true`.
2. **Langkah 2 (Penerima Mengirim Konfirmasi Baca)**:
   * Saat lawan bicara membuka layar room chat, panggil:
     ```dart
     await ChatClient.getInstance.chatManager.sendConversationReadAck(targetUserId);
     ```
3. **Langkah 3 (Pengirim Menangkap Sinyal Baca)**:
   * Di sisi pengirim, pasang callback di `ChatEventHandler`:
     ```dart
     onConversationRead: (String from, String to) {
       setState(() {
         // Tandai semua pesan yang kita kirim menjadi isRead = true
         for (var m in _messages) {
           if (m.isMe) m.isRead = true;
         }
       });
     }
     ```
4. **Langkah 4 (Render Icon di Bawah Chat)**:
   * Tampilkan waktu pengiriman + icon ceklis secara kondisional:
     * `isRead == true` → `Icons.done_all` warna **Biru Cyan (`#00E5FF`)**.
     * `isDelivered == true` → `Icons.done_all` warna **Putih/Abu**.
     * Default → `Icons.done` warna **Putih/Abu**.

---

## 6. Alur Fitur 5: Notifikasi Banner Mengambang

### 💡 Konsep Arsitektur:
Menampilkan notifikasi elegan yang melayang dari atas layar saat user sedang berada di halaman lain (Dashboard).

### 🛠️ Langkah-Langkah Development:
1. **Langkah 1 (Mencegah Notif Tumpang Tindih)**:
   * Buat variabel penanda: `String? _activeChatUserId`.
   * Saat room chat dibuka: set `_activeChatUserId = targetUser.id`.
   * Saat room chat ditutup: set `_activeChatUserId = null`.
   * Di listener global: jika `senderId == _activeChatUserId`, **abaikan banner** (karena user sedang membaca chat tersebut).
2. **Langkah 2 (Render Banner Menggunakan `OverlayEntry`)**:
   * Sisipkan widget mengambang di atas pohon widget Flutter:
     ```dart
     final entry = OverlayEntry(builder: (ctx) => Positioned(...));
     Overlay.of(context).insert(entry);
     ```
3. **Langkah 3 (Pembersihan Memory & Timer Aman)**:
   * Buat `Timer(Duration(seconds: 4), () { ... })` untuk auto-dismiss.
   * Saat banner di-tap oleh user, **batalkan timer** (`timer?.cancel()`) dan cek `if (entry.mounted) entry.remove();` untuk mencegah error crash.

---

## 7. Alur Fitur 6: Helpdesk CS Dinamis & Hapus Riwayat Chat

### 💡 Konsep Arsitektur:
Inbox Customer Service bekerja seperti Zendesk / WhatsApp Business:
* **Inbox Awal Kosong (*Empty State*)**: Tidak ada daftar penumpang statis yang di-hardcode.
* **Otomatis Muncul**: Tiket obrolan baru muncul begitu ada pesan masuk pertama kali.
* **Hapus Tiket (*Resolve*)**: CS dapat membersihkan riwayat obrolan yang sudah selesai.

### 🛠️ Langkah-Langkah Development:
1. **Langkah 1 (Memuat Obrolan Aktif Saja)**:
   * Ambil semua percakapan dari Agora database lokal:
     ```dart
     final convs = await ChatClient.getInstance.chatManager.loadAllConversations();
     ```
   * Filter: Periksa `await conv.latestMessage()`. Hanya tampilkan jika `latestMessage != null` (artinya ada riwayat chat nyata).
2. **Langkah 2 (Menampilkan Empty State vs Active List)**:
   * Jika list kosong: Tampilkan ilustrasi ramah *"Belum Ada Obrolan Masuk"*.
   * Jika list ada: Tampilkan kartu pelanggan lengkap dengan cuplikan pesan terakhir (*snippet*) dan badge pesan baru (*unread*).
3. **Langkah 3 (Hapus Percakapan & Bersihkan Memori)**:
   * Saat CS menekan tombol tempat sampah merah:
     ```dart
     await ChatClient.getInstance.chatManager.deleteConversation(
       conversationId,
       deleteMessages: true, // Hapus bersih seluruh riwayat pesan dari database lokal
     );
     ```
   * Muat ulang list inbox: tampilan otomatis kembali bersih (*Empty State*).
4. **Langkah 4 (Inisiasi Chat Proaktif)**:
   * Tambahkan tombol cepat (*ActionChip*) agar CS tetap bisa berinisiatif menghubungi driver atau penumpang terlebih dahulu tanpa menunggu mereka mengirim chat duluan.

---

## 🎯 Panduan Singkat Migrasi ke `sunjaya_mobile`

Saat Anda mengintegrasikan fitur ini ke repository utama:
1. Salin file [**`lib/driver_chat_room_screen.dart`**](file:///d:/Flutter/kisah_dummy/test_agora/lib/driver_chat_room_screen.dart) dan [**`lib/call_screen.dart`**](file:///d:/Flutter/kisah_dummy/test_agora/lib/call_screen.dart).
2. Sesuaikan sumber user ID dan Token dengan API Login backend Sunjaya yang sudah ada.
3. Pasang listener global di halaman Home / Dashboard utama penumpang dan driver.
4. Jalankan pengujian menyeluruh menggunakan panduan skenario demo yang ada di [**`PANDUAN_INBOX_DAN_HAPUS_CHAT_CS.md`**](file:///d:/Flutter/kisah_dummy/test_agora/PANDUAN_INBOX_DAN_HAPUS_CHAT_CS.md).

