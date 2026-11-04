# 📱 Panduan Implementasi Fitur Upload Foto & Media (Agora Chat SDK)
### Aplikasi Shuttle Sunjaya (Driver, Customer, & Customer Service)

Dokumen ini memuat panduan lengkap, arsitektur teknis, dan langkah demi langkah (*step-by-step*) implementasi fitur **pengiriman foto/gambar patokan dan dokumen** menggunakan **Agora Chat SDK** serta paket `image_picker` di Flutter.

---

## 📑 Daftar Isi
1. [Arsitektur Media di Agora Chat](#1-arsitektur-media-di-agora-chat)
2. [Rangkuman Update pada Project Ini (`test_agora`)](#2-rangkuman-update-pada-project-ini-test_agora)
3. [Langkah Demi Langkah (*Step-by-Step*) Implementasi ke `sunjaya_mobile`](#3-langkah-demi-langkah-step-by-step-implementasi-ke-sunjaya_mobile)
   - [Langkah 1: Tambahkan Dependency di `pubspec.yaml`](#langkah-1-tambahkan-dependency-di-pubspecyaml)
   - [Langkah 2: Konfigurasi Izin Sistem (Android & iOS)](#langkah-2-konfigurasi-izin-sistem-android--ios)
   - [Langkah 3: Update Model Data Pesan (`ShuttleChatMessage`)](#langkah-3-update-model-data-pesan-shuttlechatmessage)
   - [Langkah 4: Fungsi Pengambilan & Pengiriman Foto (`createImageSendMessage`)](#langkah-4-fungsi-pengambilan--pengiriman-foto-createimagesendmessage)
   - [Langkah 5: Menerima Pesan Foto Secara Real-Time (`onMessagesReceived`)](#langkah-5-menerima-pesan-foto-secara-real-time-onmessagesreceived)
   - [Langkah 6: Memuat Riwayat Foto dari Server & Database Lokal](#langkah-6-memuat-riwayat-foto-dari-server--database-lokal)
   - [Langkah 7: Desain UI Bubble Foto & Preview Layar Penuh (Zoom)](#langkah-7-desain-ui-bubble-foto--preview-layar-penuh-zoom)
4. [Skenario Penggunaan Nyata pada Shuttle Sunjaya](#4-skenario-penggunaan-nyata-pada-shuttle-sunjaya)
5. [Tips Optimasi & *Best Practices* Produksi](#5-tips-optimasi--best-practices-produksi)

---

## 1. Arsitektur Media di Agora Chat

### Apakah Perlu Server Storage Tambahan (AWS S3 / Firebase Storage)?
**TIDAK PERLU.** 
Agora Chat SDK sudah memiliki infrastruktur **Cloud Storage & CDN bawaan (*built-in*)**.

Alur kerjanya:
```
[Perangkat Pengirim]
       │  (1. Pilih foto dari Kamera/Galeri)
       ▼
  ImagePicker -> /cache/image_patokan.jpg
       │
       │  (2. Panggil ChatMessage.createImageSendMessage)
       ▼
  Agora Chat SDK
       │  (3. Otomatis upload file biner ke Agora CDN)
       ▼
 [Agora CDN Storage]
       │
       │  (4. Mengirimkan metadata & remote URL ke penerima)
       ▼
 [Perangkat Penerima]
       │  (5. Menerima ChatImageMessageBody)
       ├─ remotePath          -> URL gambar resolusi asli di server Agora
       ├─ thumbnailRemotePath -> URL gambar thumbnail terkompresi otomatis
       └─ localPath           -> Path lokal jika sudah terunduh otomatis
```

**Keuntungan bagi Shuttle Sunjaya:**
1. **Zero Backend Maintenance:** Tidak perlu repot membuat endpoint REST API upload multipart/form-data di backend Laravel/Go/Node.js.
2. **Hemat Biaya:** Tidak perlu membayar tagihan terpisah untuk AWS S3 atau Google Cloud Storage.
3. **Thumbnail Otomatis:** Agora secara otomatis men-generate versi thumbnail kecil berukuran ringan sehingga daftar chat tidak lag saat dibuka.

---

## 2. Rangkuman Update pada Project Ini (`test_agora`)

Berikut berkas yang telah diperbarui dan ditambahkan di repositori ini:
1. `pubspec.yaml`:
   - Menambahkan dependency `image_picker: ^1.1.2`.
2. `lib/driver_chat_room_screen.dart`:
   - **Model Data:** Menambahkan `ShuttleMessageType` (tipe `text` & `image`), serta properti `localPath`, `remoteUrl`, `thumbnailUrl`, dan getter `isImage`.
   - **Logika Kirim:** Menambahkan method `_pickAndSendImage(ImageSource source)` yang mengompresi gambar dan memanggil `ChatMessage.createImageSendMessage`.
   - **Logika Terima:** Menambahkan penanganan `MessageType.IMAGE` pada `_setupAgoraListener` dan `_loadAgoraHistory`.
   - **UI Input:** Menambahkan tombol kamera `Icons.add_a_photo_outlined` pada bar input bawah.
   - **UI Action Sheet:** Modal bottom sheet pilihan "Kamera" (ambil langsung) atau "Galeri" (pilih foto yang sudah ada).
   - **UI Bubble Chat:** Menampilkan kartu foto berbingkai rapi, label "Foto Patokan", waktu pengiriman, dan tanda centang ganda.
   - **UI Preview Fullscreen:** Menambahkan dialog preview foto interaktif dengan `InteractiveViewer` (bisa di-zoom/cubit dan digeser).

---

## 3. Langkah Demi Langkah (*Step-by-Step*) Implementasi ke `sunjaya_mobile`

### Langkah 1: Tambahkan Dependency di `pubspec.yaml`
Buka berkas `pubspec.yaml` di project utama `sunjaya_mobile`, lalu tambahkan:
```yaml
dependencies:
  flutter:
    sdk: flutter
  agora_chat_sdk: ^1.4.0+1
  image_picker: ^1.1.2
```
Jalankan perintah:
```bash
flutter pub get
```

---

### Langkah 2: Konfigurasi Izin Sistem (Android & iOS)

#### A. Konfigurasi Android (`android/app/src/main/AndroidManifest.xml`)
Pastikan izin kamera dan internet sudah terpasang di dalam tag `<manifest>`:
```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <uses-permission android:name="android.permission.INTERNET"/>
    <uses-permission android:name="android.permission.CAMERA"/>
    <!-- Untuk Android 12 kebawah jika ingin membaca penyimpanan external -->
    <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" android:maxSdkVersion="32"/>
    
    <application
        ...
    </application>
</manifest>
```
> **Catatan Penting Android 13+ (API 33+):** Paket `image_picker` terbaru secara otomatis menggunakan *Android Photo Picker* bawaan OS yang **tidak memerlukan izin penyimpanan khusus**, sehingga sangat aman dan sesuai dengan kebijakan Google Play Store terbaru.

#### B. Konfigurasi iOS (`ios/Runner/Info.plist`)
Jika aplikasi dijalankan di iPhone / iOS, tambahkan deskripsi izin berikut:
```xml
<key>NSCameraUsageDescription</key>
<string>Sunjaya Shuttle membutuhkan akses kamera untuk mengambil foto patokan penjemputan.</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>Sunjaya Shuttle membutuhkan akses galeri untuk mengunggah foto patokan penjemputan.</string>
```

---

### Langkah 3: Update Model Data Pesan (`ShuttleChatMessage`)
Buat enum tipe pesan dan lengkapi model pesan agar mendukung foto:

```dart
/// Tipe pesan chat shuttle
enum ShuttleMessageType {
  text,
  image,
}

/// Model data pesan obrolan antara Penumpang, Driver, dan CS
class ShuttleChatMessage {
  final ShuttleMessageType type; // text atau image
  final String text;             // Isi teks pesan atau nama file foto
  final bool isMe;               // true jika dikirim oleh akun kita sendiri
  final DateTime time;           // Waktu pesan dikirim
  final String? localPath;       // Path lokal di HP (jika baru diambil dari kamera)
  final String? remoteUrl;       // URL foto penuh di CDN Agora Cloud
  final String? thumbnailUrl;    // URL thumbnail foto di CDN Agora Cloud
  final int? fileSize;

  ShuttleChatMessage({
    this.type = ShuttleMessageType.text,
    required this.text,
    required this.isMe,
    required this.time,
    this.localPath,
    this.remoteUrl,
    this.thumbnailUrl,
    this.fileSize,
  });

  bool get isImage => type == ShuttleMessageType.image;
}
```

---

### Langkah 4: Fungsi Pengambilan & Pengiriman Foto (`createImageSendMessage`)

Gunakan `ImagePicker` untuk mengambil foto, lalu kirim melalui `ChatMessage.createImageSendMessage`:

```dart
import 'dart:io';
import 'package:agora_chat_sdk/agora_chat_sdk.dart';
import 'package:image_picker/image_picker.dart';

final ImagePicker _picker = ImagePicker();
bool _isUploadingImage = false;

Future<void> _pickAndSendImage(ImageSource source) async {
  try {
    // 1. Ambil foto dari Kamera atau Galeri dengan kompresi optimal
    final XFile? pickedFile = await _picker.pickImage(
      source: source,
      imageQuality: 70, // Kompresi 70% agar cepat terkirim dan hemat kuota
      maxWidth: 1280,   // Resolusi maksimal 1280px (sangat cukup untuk patokan jalan)
      maxHeight: 1280,
    );

    if (pickedFile == null) return; // Pengguna membatalkan

    final filePath = pickedFile.path;
    final fileName = pickedFile.name;

    setState(() {
      _isUploadingImage = true;
    });

    // 2. Buat objek pesan gambar Agora Chat
    final msg = ChatMessage.createImageSendMessage(
      targetId: widget.targetUserId, // ID Agora Driver / Penumpang / CS
      filePath: filePath,
      displayName: fileName,
      sendOriginalImage: false,      // Kirim versi terkompresi
    );

    // 3. Kirim via SDK (Agora otomatis mengunggah file ke CDN Agora)
    await ChatClient.getInstance.chatManager.sendMessage(msg);

    // 4. Tambahkan langsung ke UI lokal (Optimistic UI)
    if (mounted) {
      setState(() {
        _messages.add(
          ShuttleChatMessage(
            type: ShuttleMessageType.image,
            text: fileName,
            isMe: true,
            time: DateTime.now(),
            localPath: filePath,
          ),
        );
        _isUploadingImage = false;
      });
      _scrollToBottom();
    }
  } catch (e) {
    debugPrint("❌ Gagal mengirim gambar: $e");
    if (mounted) {
      setState(() {
        _isUploadingImage = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Gagal mengirim foto: $e")),
      );
    }
  }
}
```

---

### Langkah 5: Menerima Pesan Foto Secara Real-Time (`onMessagesReceived`)

Di dalam listener Agora `ChatEventHandler`, tambahkan pengecekan `msg.body.type == MessageType.IMAGE`:

```dart
ChatClient.getInstance.chatManager.addEventHandler(
  "SHUTTLE_CHAT_HANDLER",
  ChatEventHandler(
    onMessagesReceived: (List<ChatMessage> messages) {
      for (var msg in messages) {
        final sender = msg.from?.trim().toLowerCase() ?? '';
        final expectedTarget = widget.targetUserId.trim().toLowerCase();

        if (sender == expectedTarget) {
          final timestamp = msg.serverTime > 0
              ? msg.serverTime
              : (msg.localTime > 0 ? msg.localTime : DateTime.now().millisecondsSinceEpoch);

          // A. PESAN TEKS
          if (msg.body.type == MessageType.TXT) {
            final body = msg.body as ChatTextMessageBody;
            _addMessageToUI(ShuttleChatMessage(
              type: ShuttleMessageType.text,
              text: body.content,
              isMe: false,
              time: DateTime.fromMillisecondsSinceEpoch(timestamp),
            ));
          }
          // B. PESAN FOTO / GAMBAR MASUK
          else if (msg.body.type == MessageType.IMAGE) {
            final body = msg.body as ChatImageMessageBody;
            _addMessageToUI(ShuttleChatMessage(
              type: ShuttleMessageType.image,
              text: body.displayName ?? 'Foto Lampiran',
              isMe: false,
              time: DateTime.fromMillisecondsSinceEpoch(timestamp),
              localPath: body.localPath,
              remoteUrl: body.remotePath,
              thumbnailUrl: body.thumbnailRemotePath ?? body.remotePath,
              fileSize: body.fileSize,
            ));
          }
        }
      }
    },
  ),
);
```

---

### Langkah 6: Memuat Riwayat Foto dari Server & Database Lokal

Saat layar dibuka, panggil `conversation.loadMessages` atau `fetchHistoryMessagesByOption`. Pastikan cabang `MessageType.IMAGE` ikut diparsing:

```dart
for (var msg in list) {
  final isMe = msg.from == widget.currentUserId;
  final timestamp = msg.serverTime > 0 ? msg.serverTime : msg.localTime;

  if (msg.body.type == MessageType.TXT) {
    if (msg.attributes != null && msg.attributes!["action"] == "CALL_INVITE") continue;
    final body = msg.body as ChatTextMessageBody;
    history.add(
      ShuttleChatMessage(
        type: ShuttleMessageType.text,
        text: body.content,
        isMe: isMe,
        time: DateTime.fromMillisecondsSinceEpoch(timestamp),
      ),
    );
  } else if (msg.body.type == MessageType.IMAGE) {
    final body = msg.body as ChatImageMessageBody;
    history.add(
      ShuttleChatMessage(
        type: ShuttleMessageType.image,
        text: body.displayName ?? 'Foto Lampiran',
        isMe: isMe,
        time: DateTime.fromMillisecondsSinceEpoch(timestamp),
        localPath: body.localPath,
        remoteUrl: body.remotePath,
        thumbnailUrl: body.thumbnailRemotePath ?? body.remotePath,
        fileSize: body.fileSize,
      ),
    );
  }
}
```

---

### Langkah 7: Desain UI Bubble Foto & Preview Layar Penuh (Zoom)

#### A. Widget Penampil Gambar (`_buildImageContent`)
Memprioritaskan file lokal (jika baru kita ambil dari HP sendiri), lalu fallback ke URL remote dari Agora Cloud CDN:

```dart
Widget _buildImageContent(ShuttleChatMessage msg, {BoxFit fit = BoxFit.cover}) {
  // 1. Cek file lokal di memori HP
  if (msg.localPath != null &&
      msg.localPath!.isNotEmpty &&
      File(msg.localPath!).existsSync()) {
    return Image.file(
      File(msg.localPath!),
      fit: fit,
      errorBuilder: (_, __, ___) => _buildPlaceholderError(),
    );
  }

  // 2. Gunakan URL remote Agora CDN
  final url = msg.remoteUrl ?? msg.thumbnailUrl;
  if (url != null && url.isNotEmpty) {
    return Image.network(
      url,
      fit: fit,
      loadingBuilder: (context, child, progress) {
        if (progress == null) return child;
        return Container(
          height: 180,
          color: Colors.grey.shade100,
          alignment: Alignment.center,
          child: const CircularProgressIndicator(strokeWidth: 2),
        );
      },
      errorBuilder: (_, __, ___) => _buildPlaceholderError(),
    );
  }

  return _buildPlaceholderError();
}
```

#### B. Dialog Preview Layar Penuh (Pinch-to-Zoom)
Gunakan `InteractiveViewer` bawaan Flutter agar pengguna bisa memperbesar foto yang buram atau detail tiket:

```dart
void _showImagePreviewDialog(ShuttleChatMessage msg) {
  showDialog(
    context: context,
    builder: (dialogCtx) => Dialog(
      backgroundColor: Colors.black.withOpacity(0.92),
      insetPadding: EdgeInsets.zero,
      child: Stack(
        children: [
          InteractiveViewer(
            panEnabled: true,
            minScale: 0.8,
            maxScale: 4.0, // Bisa zoom hingga 4x
            child: Center(
              child: _buildImageContent(msg, fit: BoxFit.contain),
            ),
          ),
          Positioned(
            top: 40,
            left: 16,
            child: CircleAvatar(
              backgroundColor: Colors.black54,
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.white),
                onPressed: () => Navigator.of(dialogCtx).pop(),
              ),
            ),
          ),
          Positioned(
            bottom: 30,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _formatTime(msg.time),
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
```

#### C. Gelembung Obrolan Gambar Bersih (*Clean Image Bubble*)
Menampilkan gambar secara murni tanpa teks judul tambahan, dengan badge waktu dan tanda centang ganda semi-transparan di pojok kanan bawah (seperti WhatsApp / Telegram):

```dart
Widget _buildImageBubble(ShuttleChatMessage msg, bool isMe) {
  return Align(
    alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
    child: Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.72,
      ),
      decoration: BoxDecoration(
        color: isMe ? COLORS.primary : Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: InkWell(
        onTap: () => _showImagePreviewDialog(msg),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxHeight: 260,
                    minWidth: double.infinity,
                  ),
                  child: _buildImageContent(msg, fit: BoxFit.cover),
                ),
              ),
              Positioned(
                bottom: 6,
                right: 6,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.55),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _formatTime(msg.time),
                        style: const TextStyle(fontSize: 10, color: Colors.white),
                      ),
                      if (isMe) ...[
                        const SizedBox(width: 4),
                        const Icon(Icons.done_all, size: 13, color: Colors.white),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
```

---

## 4. Skenario Penggunaan Nyata pada Shuttle Sunjaya

| Aktor Pengirim | Aktor Penerima | Contoh Foto yang Dikirim | Manfaat Operasional |
| :--- | :--- | :--- | :--- |
| **Penumpang** | **Driver** | Foto pagar rumah, plang toko, lobi apartemen, atau gang masuk. | Driver tidak tersesat atau salah menunggu lobi, mempercepat waktu penjemputan armada hingga 40%. |
| **Driver** | **Penumpang** | Foto plat nomor mobil shuttle, posisi parkir di pinggir jalan / terminal. | Penumpang langsung mengenali mobil shuttle yang menjemputnya di keramaian stasiun/bandara. |
| **Customer** | **Customer Service (CS)** | Foto bukti transfer bank / struk pembayaran, tiket fisik, perubahan jadwal. | Verifikasi instan dan penyelesaian klaim tiket tanpa perlu email manual. |
| **Driver** | **Customer Service (CS)** | Foto barang penumpang yang tertinggal di kursi mobil (*Lost and Found*). | CS bisa langsung mencocokkan dengan manifes tiket penumpang yang komplain. |

---

## 5. Tips Optimasi & *Best Practices* Produksi

1. **Kompresi Wajib Sisi Klien:**
   Jangan pernah mengirim gambar asli dari kamera modern (yang biasanya berukuran 5MB - 15MB). Selalu set:
   ```dart
   imageQuality: 70,
   maxWidth: 1280,
   maxHeight: 1280,
   ```
   Ini akan memangkas ukuran foto menjadi **100KB - 300KB** saja, membuat pengiriman instan bahkan di jaringan 3G/4G jalan tol yang lemah.

2. **Optimistic UI:**
   Begitu pengguna menekan "Kirim", langsung masukkan foto ke daftar obrolan lokal dengan `localPath`. Jangan menunggu respon jaringan selesai baru menampilkan foto, agar aplikasi terasa sangat cepat (*snappy*).

3. **Status Pengunggahan:**
   Tampilkan indikator kecil (*progress bar*) di atas kolom input teks saat foto sedang diunggah ke CDN Agora agar pengguna tahu proses sedang berlangsung.

4. **Koneksi Terputus:**
   Jika pengguna offline di area *blank spot* (misal di pegunungan / basement), Agora Chat SDK akan mengantrekan (*queue*) pesan tersebut dan otomatis mengirimkannya begitu koneksi internet pulih.

---
*Dibuat untuk Tim Pengembang Sunjaya Shuttle Mobile Application.*

