# 💬 Panduan Lengkap Implementasi AGORA CHAT di Proyek Shuttle Antar-Jemput

Panduan ini dibuat khusus agar Anda dapat memindahkan kode obrolan (*chatting*) dari proyek percobaan (`test_agora`) ke **Real Project Shuttle Anda**, dengan arsitektur bersih, aman, dan mudah diintegrasikan ke tampilan UI custom Anda.

---

## 📌 DAFTAR ISI
1. [Arsitektur Chat di Aplikasi Shuttle](#1-arsitektur-chat-di-aplikasi-shuttle)
2. [Langkah 1: Setup Dependensi & Izin](#langkah-1-setup-dependensi--izin)
3. [Langkah 2: Data yang Disediakan Backend Laravel](#langkah-2-data-yang-disediakan-backend-laravel)
4. [Langkah 3: Bedah Fungsi & Alur Kodingan (Function by Function)](#langkah-3-bedah-fungsi--alur-kodingan)
5. [Langkah 4: Fitur Kirim Foto Titik Jemput & Lokasi](#langkah-4-fitur-kirim-foto-titik-jemput--lokasi)
6. [Langkah 5: Cara Menghubungkan ke UI Custom Anda](#langkah-5-cara-menghubungkan-ke-ui-custom-anda)

---

## 1. Arsitektur Chat di Aplikasi Shuttle

Pada aplikasi shuttle antar-jemput, komunikasi chat dilakukan antara:
* **Driver Shuttle** (pengemudi armada)
* **Penumpang** (pemesan tiket antar-jemput tertentu)

Setiap sesi obrolan bersifat **1-on-1 Privat** berdasarkan tiket/booking penjemputan.

```
[PENUMPANG]                                                          [DRIVER]
     |                                                                   |
     |-- 1. Login Akun via Laravel (Dapat: userId & chatToken)           |-- 1. Login Akun Driver
     |-- 2. ChatClient.getInstance.loginWithToken(userId, chatToken)     |-- 2. Login ke Agora Chat
     |                                                                   |
     |================== 3. Mengirim Pesan Teks / Foto =================>|
     |                   targetId: "driver_5"                            |
     |                                                                   |
     |<================= 4. Driver Membalas Pesan =======================|
     |                   targetId: "cust_12"                             |
```

---

## Langkah 1: Setup Dependensi & Izin

### 1. File `pubspec.yaml`
Tambahkan package Agora Chat dan pendukung media di proyek Anda:
```yaml
dependencies:
  flutter:
    sdk: flutter
  agora_chat_sdk: ^1.4.0+1   # SDK Chat Resmi Agora
  image_picker: ^1.1.2       # Untuk mengambil foto patokan/titik jemput
```

### 2. File `android/app/src/main/AndroidManifest.xml`
Pastikan izin jaringan telah terpasang sebelum tag `<application>`:
```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <uses-permission android:name="android.permission.INTERNET"/>
    <uses-permission android:name="android.permission.ACCESS_NETWORK_STATE"/>
    <application ...>
```

---

## Langkah 2: Data yang Disediakan Backend Laravel

Di proyek nyata, Anda tidak mengetik kredensial secara manual. Saat user login dengan Google di Flutter, Laravel mengembalikan payload seperti ini:

```json
{
  "user_id": "user_25",
  "agora_chat_token": "007eJxTYLi7aPs6rp...",
  "agora_app_key": "61200084352#200118764"
}
```

Dan saat membuka detail booking shuttle penjemputan, aplikasi tahu siapa lawan bicaranya:
* Jika aplikasi Penumpang: `targetUserId = "driver_4"`
* Jika aplikasi Driver: `targetUserId = "user_25"`

---

## Langkah 3: Bedah Fungsi & Alur Kodingan

Berikut adalah struktur kode chat yang siap Anda gunakan di controller / state management (Cubit/Bloc/GetX/StatefulWidget) Anda:

### 1. Inisialisasi SDK (`initAgoraChat`)
Dipanggil **satu kali** saat aplikasi dibuka atau saat modul chat dimulai:

```dart
Future<void> initAgoraChat(String appKey) async {
  // 1. Buat konfigurasi chat
  ChatOptions options = ChatOptions.withAppKey(
    appKey,
    autoLogin: false, // Disarankan false agar login dikontrol manual via token
  );

  // Otomatis unduh thumbnail gambar agar tampilan chat langsung muncul
  options.autoDownloadThumbnail = true;

  // 2. Inisialisasi engine Agora Chat
  await ChatClient.getInstance.init(options);

  // 3. Wajib: aktifkan callback jembatan native agar event listener bekerja
  await ChatClient.getInstance.startCallback();

  // 4. Pasang listener pesan masuk
  setupChatListeners();
}
```
* **Kegunaan:** Menghubungkan aplikasi Flutter ke server cluster Agora Chat menggunakan `appKey`.
* **Kapan dipanggil?** Saat `initState()` atau splash screen setelah mendapatkan `appKey`.

---

### 2. Memasang Listener Pesan Masuk (`setupChatListeners`)
Fungsi ini bertindak sebagai "telinga" aplikasi untuk menangkap pesan yang datang dari lawan bicara secara real-time:

```dart
void setupChatListeners() {
  ChatClient.getInstance.chatManager.addEventHandler(
    "CHAT_SHUTTLE_LISTENER",
    ChatEventHandler(
      onMessagesReceived: (List<ChatMessage> messages) {
        for (var msg in messages) {
          // Hanya proses pesan jika pengirimnya adalah lawan bicara yang sedang kita buka
          if (msg.from == targetUserId) {
            
            // A. Cek jika pesan adalah Teks
            if (msg.body.type == MessageType.TXT) {
              ChatTextMessageBody body = msg.body as ChatTextMessageBody;
              addMessageToUI(sender: msg.from!, text: body.content, isMe: false);
            }
            
            // B. Cek jika pesan adalah Gambar/Foto
            else if (msg.body.type == MessageType.IMAGE) {
              ChatImageMessageBody body = msg.body as ChatImageMessageBody;
              addImageToUI(sender: msg.from!, localPath: body.thumbnailLocalPath, remoteUrl: body.remotePath, isMe: false);
            }
          }
        }
      },
    ),
  );

  // Listener untuk memantau apakah pesan yang KITA kirim berhasil sampai ke server Agora
  ChatClient.getInstance.chatManager.addMessageEvent(
    "MESSAGE_STATUS_LISTENER",
    ChatMessageEvent(
      onSuccess: (msgId, msg) {
        debugPrint("Pesan $msgId sukses terkirim ke server Agora.");
      },
      onError: (msgId, msg, error) {
        debugPrint("Pesan $msgId gagal terkirim: ${error.description}");
      },
    ),
  );
}
```
* **`onMessagesReceived`:** Dipicu otomatis oleh Agora server setiap kali ada pesan masuk ke akun kita.
* **`addMessageEvent`:** Memberikan callback status centang satu / berhasil terkirim ke server.

---

### 3. Login Akun ke Agora Chat (`loginToAgora`)
Dipanggil setelah aplikasi berhasil login ke backend Laravel:

```dart
Future<bool> loginToAgora(String userId, String chatToken) async {
  try {
    await ChatClient.getInstance.loginWithToken(userId, chatToken);
    debugPrint("Berhasil login ke Agora Chat sebagai $userId");
    
    // Setelah login berhasil, muat riwayat pesan terdahulu dari database lokal
    await loadChatHistory();
    return true;
  } on ChatError catch (e) {
    debugPrint("Gagal login Agora (${e.code}): ${e.description}");
    return false;
  }
}
```
* **Kegunaan:** Mengautentikasi koneksi socket user ke Agora Chat menggunakan User Token.
* **Catatan Penting:** Token harus sesuai dengan User ID-nya.

---

### 4. Mengambil Riwayat Pesan Terdahulu (`loadChatHistory`)
Agora Chat secara otomatis menyimpan percakapan di database SQLite internal HP pengguna:

```dart
Future<void> loadChatHistory() async {
  try {
    ChatConversation? conversation = await ChatClient.getInstance.chatManager
        .getConversation(targetUserId);

    if (conversation != null) {
      // Ambil 50 pesan terakhir dari database lokal
      List<ChatMessage> list = await conversation.loadMessages(
        startMsgId: '',
        loadCount: 50,
        direction: ChatSearchDirection.Up, // Up = dari pesan terbaru ke lama
      );

      // Balikkan urutan list agar pesan lama berada di atas dan pesan baru di bawah
      for (var msg in list.reversed) {
        if (msg.body.type == MessageType.TXT) {
          ChatTextMessageBody body = msg.body as ChatTextMessageBody;
          addMessageToUI(
            sender: msg.from ?? '',
            text: body.content,
            isMe: msg.from == currentUserId,
          );
        }
      }
    }
  } catch (e) {
    debugPrint("Error load history: $e");
  }
}
```
* **Kegunaan:** Saat penumpang/driver menutup aplikasi dan membukanya lagi, riwayat chat sebelumnya tidak hilang.

---

### 5. Mengirim Pesan Teks (`sendTextMessage`)
```dart
Future<void> sendTextMessage(String text) async {
  if (text.trim().isEmpty) return;

  // 1. Buat paket pesan teks dengan target ID lawan bicara
  final msg = ChatMessage.createTxtSendMessage(
    targetId: targetUserId,
    content: text.trim(),
  );

  try {
    // 2. Kirim pesan melalui chatManager
    await ChatClient.getInstance.chatManager.sendMessage(msg);

    // 3. Tampilkan pesan kita sendiri di layar UI
    addMessageToUI(
      sender: currentUserId,
      text: text.trim(),
      isMe: true,
    );
  } catch (e) {
    debugPrint("Gagal kirim pesan: $e");
  }
}
```

---

### 6. Membersihkan Listener saat Keluar Halaman (`dispose`)
Wajib dilepas agar tidak terjadi kebocoran memori (*memory leak*):

```dart
@override
void dispose() {
  ChatClient.getInstance.chatManager.removeEventHandler("CHAT_SHUTTLE_LISTENER");
  ChatClient.getInstance.chatManager.removeMessageEvent("MESSAGE_STATUS_LISTENER");
  super.dispose();
}
```

---

## Langkah 4: Fitur Kirim Foto Titik Jemput & Lokasi

Untuk layanan antar-jemput shuttle, fitur ini sangat penting agar driver mudah menemukan titik jemput:

### A. Mengirim Foto Patokan Rumah / Lobi
```dart
import 'package:image_picker/image_picker.dart';

Future<void> sendImagePatokan() async {
  final picker = ImagePicker();
  final XFile? file = await picker.pickImage(
    source: ImageSource.camera,
    imageQuality: 70, // Kompres sedikit agar hemat kuota
  );
  if (file == null) return;

  // 1. Buat pesan gambar Agora (Cukup masukkan path file lokal di HP)
  final msg = ChatMessage.createImageSendMessage(
    targetId: targetUserId,
    filePath: file.path,
    sendOriginalImage: false,
  );

  // 2. Kirim (Agora otomatis mengunggah file ke cloud storage miliknya)
  await ChatClient.getInstance.chatManager.sendMessage(msg);

  // 3. Tampilkan pratinjau lokal di UI kita
  addImageToUI(sender: currentUserId, localPath: file.path, isMe: true);
}
```

### B. Mengirim Koordinat GPS Titik Jemput
```dart
Future<void> sendTitikJemputGPS({
  required double latitude,
  required double longitude,
  required String namaLokasi,
}) async {
  final msg = ChatMessage.createLocationSendMessage(
    targetId: targetUserId,
    latitude: latitude,
    longitude: longitude,
    address: namaLokasi, // Contoh: "Pagar Hitam No. 12, Jl. Melati"
  );

  await ChatClient.getInstance.chatManager.sendMessage(msg);
}
```

---

## Langkah 5: Cara Menghubungkan ke UI Custom Anda (DriverChatSheet)

Proyek ini telah diperbarui menggunakan UI **`DriverChatSheet`** (Modal Bottom Sheet) yang sudah langsung siap dipindahkan ke proyek real Anda (`sunjaya_mobile`):

### 1. File Siap Pakai: `lib/driver_chat_sheet.dart`
File ini berisi:
* **Model Pesan:** `DriverChatMessage(text, isMe, time)`
* **Fungsi Pembuka:** `showDriverChatSheet(context, driverName: ..., targetUserId: ..., currentUserId: ...)`
* **Balon Chat:** Tampilan gelembung chat modern dengan indikator waktu, centang ganda (`Icons.done_all`), dan warna tema `COLORS.primary`.
* **Quick Replies:** Chip cepat (*"Saya sudah di lokasi jemput"*, *"Mohon tunggu sebentar"*, dll).
* **Header Aksi:** Status *Driver • Online*, Tombol Panggilan Suara (Voice Call), Tombol Panggilan Video (Video Call), dan Tombol Tutup.

### 2. Cara Memanggil dari Layar Pelacakan / Booking Shuttle:
```dart
// Di layar pelacakan armada (misal: LokasiDriverScreen)
ElevatedButton(
  onPressed: () {
    showDriverChatSheet(
      context,
      driverName: 'Pak Dika (Driver Shuttle)',
      targetUserId: 'dhika-driver',
      currentUserId: 'dhadi-cust',
    );
  },
  child: const Text("Hubungi Driver (Buka Chat)"),
)
```

Dengan struktur di atas, logika Agora Chat dan UI Bottom Sheet Anda sudah terpadu rapi, sehingga Anda cukup menyalin file [lib/driver_chat_sheet.dart](lib/driver_chat_sheet.dart) dan [lib/core/res/colors.dart](lib/core/res/colors.dart) ke dalam proyek real Anda!

