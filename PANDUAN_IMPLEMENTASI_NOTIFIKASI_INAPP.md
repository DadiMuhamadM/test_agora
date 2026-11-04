# 🔔 Panduan Implementasi Fitur In-App Notification & Unread Badge (Agora Chat SDK)
### Aplikasi Shuttle Sunjaya (Driver, Customer, & Customer Service)

Dokumen ini memuat panduan lengkap, arsitektur teknis, dan langkah demi langkah (*step-by-step*) implementasi fitur **Notifikasi Dalam Aplikasi (*In-App Floating Banner*)** dan **Badge Pesan Belum Dibaca (*Unread Message Badge*)** menggunakan **Agora Chat SDK** di Flutter.

---

## 📑 Daftar Isi
1. [Konsep & Cara Kerja In-App Notification](#1-konsep--cara-kerja-in-app-notification)
2. [Perbedaan In-App Notification vs Offline Push Notification](#2-perbedaan-in-app-notification-vs-offline-push-notification)
3. [Rangkuman Fitur yang Sudah Diterapkan di Project Ini](#3-rangkuman-fitur-yang-sudah-diterapkan-di-project-ini)
4. [Langkah Demi Langkah (*Step-by-Step*) Implementasi ke `sunjaya_mobile`](#4-langkah-demi-langkah-step-by-step-implementasi-ke-sunjaya_mobile)
   - [Langkah 1: Siapkan State Penyimpan Jumlah Pesan Belum Dibaca](#langkah-1-siapkan-state-penyimpan-jumlah-pesan-belum-dibaca)
   - [Langkah 2: Pasang Global Event Handler di Layar Utama / Dashboard](#langkah-2-pasang-global-event-handler-di-layar-utama--dashboard)
   - [Langkah 3: Sinkronisasi Pesan Belum Dibaca dari Server Agora](#langkah-3-sinkronisasi-pesan-belum-dibaca-dari-server-agora)
   - [Langkah 4: Bangun Komponen Floating Banner Notifikasi](#langkah-4-bangun-komponen-floating-banner-notifikasi)
   - [Langkah 5: Tampilkan Badge Merah pada Kartu & Tombol Chat](#langkah-5-tampilkan-badge-merah-pada-kartu--tombol-chat)
   - [Langkah 6: Tandai Pesan sebagai Terbaca saat Room Chat Dibuka](#langkah-6-tandai-pesan-sebagai-terbaca-saat-room-chat-dibuka)
5. [Panduan Praktis Demo Interaktif ke Atasan](#5-panduan-praktis-demo-interaktif-ke-atasan)

---

## 1. Konsep & Cara Kerja In-App Notification

Fitur **In-App Notification** aktif saat pengguna sedang membuka aplikasi (misalnya Driver sedang melihat rute jalan, Penumpang sedang mengecek status tiket, atau CS sedang di dashboard antrean).

Ketika lawan bicara mengirimkan pesan (baik teks maupun foto), aplikasi akan:
1. **Mendeteksi Pesan Masuk secara Real-Time** melalui listener global Agora Chat SDK (`onMessagesReceived`).
2. **Menghitung Pesan Belum Dibaca** untuk pengirim tersebut.
3. **Memunculkan Floating Banner di Bagian Atas Layar** yang meluncur turun halus (*slide animation*), menampilkan foto profil/ikon peran, nama pengirim, dan cuplikan isi pesan.
4. **Memberikan Aksi Ketukan (*Tap to Open*):** Jika banner diketuk, aplikasi langsung membuka room chat dengan pengirim tersebut.
5. **Memperbarui Badge Merah:** Angka `🔴 1 Baru`, `🔴 2 Baru` otomatis bertambah di kartu lawan bicara tanpa perlu *reload* halaman.

---

## 2. Perbedaan In-App Notification vs Offline Push Notification

| Kategori | In-App Notification (Fitur Ini) | Offline Push Notification (FCM/APNs) |
| :--- | :--- | :--- |
| **Kondisi Pengguna** | Aplikasi sedang dibuka (*Foreground* / aktif di layar). | Aplikasi ditutup total (*Killed*) atau layar HP terkunci (*Background*). |
| **Jalur Pengiriman** | WebSocket bawaan Agora Chat SDK (Instan < 100ms). | Server Agora ➔ Google FCM / Apple APNs ➔ System Tray HP. |
| **Kebutuhan Server** | **Tidak butuh server luar** (100% kode Flutter). | Butuh akun Firebase Console, upload sertifikat FCM ke Agora Console. |
| **Kapan Dipakai** | Selalu aktif saat aplikasi sedang digunakan pengguna. | Untuk membangunkan HP driver/penumpang saat HP di saku. |

---

## 3. Rangkuman Fitur yang Sudah Diterapkan di Project Ini

Berikut pembaruan yang telah aktif di `test_agora`:
1. **Layar Utama ([`lib/main.dart`](file:///d:/Flutter/kisah_dummy/test_agora/lib/main.dart)):**
   * `_unreadCounts`: Map penyimpan jumlah pesan belum dibaca per `userId`.
   * `_setupGlobalMessageAndCallListener()`: Menangani pesan teks, foto, dan panggilan suara/video dari mana saja di aplikasi.
   * `_showInAppNotificationBanner()`: Banner melayang elegan (*dark theme*) dengan animasi turun dari atas, tombol tutup cepat, dan auto-dismiss 4 detik.
   * `_buildUnreadBadge()`: Badge merah `[count] Baru` di samping nama dan tombol chat.
2. **Layar Room Chat ([`lib/driver_chat_room_screen.dart`](file:///d:/Flutter/kisah_dummy/test_agora/lib/driver_chat_room_screen.dart)):**
   * Otomatis memanggil `conversation.markAllMessagesAsRead()` saat room dibuka.
   * Menampilkan SnackBar floating jika ada pesan masuk dari user lain saat driver sedang membuka chat penumpang lain.

---

## 4. Langkah Demi Langkah (*Step-by-Step*) Implementasi ke `sunjaya_mobile`

### Langkah 1: Siapkan State Penyimpan Jumlah Pesan Belum Dibaca
Di dalam State halaman utama (`StatefulWidget` dashboard atau State Management GetX/Bloc/Provider), deklarasikan variabel penampung:

```dart
// Map yang mencatat berapa pesan belum dibaca dari setiap userId lawan bicara
final Map<String, int> _unreadCounts = {};

// Variabel untuk mengontrol banner melayang
OverlayEntry? _currentNotificationOverlay;
Timer? _notificationDismissTimer;
```

---

### Langkah 2: Pasang Global Event Handler di Layar Utama / Dashboard

Daftarkan event handler Agora Chat saat inisialisasi aplikasi agar pesan masuk selalu tertangkap meskipun pengguna tidak sedang berada di dalam room chat:

```dart
void _setupGlobalMessageListener() {
  // Lepas handler lama jika ada agar tidak double listener
  ChatClient.getInstance.chatManager.removeEventHandler("GLOBAL_APP_HANDLER");

  ChatClient.getInstance.chatManager.addEventHandler(
    "GLOBAL_APP_HANDLER",
    ChatEventHandler(
      onMessagesReceived: (List<ChatMessage> messages) {
        for (var msg in messages) {
          // Abaikan sinyal internal telepon jika ada
          if (msg.attributes != null && msg.attributes!["action"] == "CALL_INVITE") {
            continue;
          }

          final senderId = msg.from ?? "";
          if (senderId.isEmpty || senderId == currentUserId) continue;

          // Ekstrak cuplikan pesan
          String previewText = "";
          if (msg.body.type == MessageType.TXT) {
            previewText = (msg.body as ChatTextMessageBody).content;
          } else if (msg.body.type == MessageType.IMAGE) {
            previewText = "📷 Mengirim sebuah foto";
          } else {
            previewText = "Mengirim pesan baru";
          }

          // 1. Tambah jumlah unread di state lokal
          setState(() {
            _unreadCounts[senderId] = (_unreadCounts[senderId] ?? 0) + 1;
          });

          // 2. Munculkan banner notifikasi melayang di atas layar
          _showInAppNotificationBanner(
            senderId: senderId,
            senderName: getSenderName(senderId), // Ambil nama dari kontak/manifes
            messagePreview: previewText,
          );
        }
      },
    ),
  );
}
```

---

### Langkah 3: Sinkronisasi Pesan Belum Dibaca dari Server Agora

Saat pengguna login atau membuka aplikasi, baca riwayat unread count dari database lokal Agora:

```dart
Future<void> _refreshUnreadCounts() async {
  try {
    final Map<String, int> counts = {};

    // Ambil semua percakapan yang tersimpan di perangkat
    List<ChatConversation> conversations =
        await ChatClient.getInstance.chatManager.loadAllConversations();

    for (var conv in conversations) {
      final unread = await conv.unreadCount();
      counts[conv.id] = unread;
    }

    if (mounted) {
      setState(() {
        _unreadCounts.clear();
        _unreadCounts.addAll(counts);
      });
    }
  } catch (e) {
    debugPrint("Gagal memuat unread counts: $e");
  }
}
```

---

### Langkah 4: Bangun Komponen Floating Banner Notifikasi

Gunakan `OverlayEntry` bawaan Flutter agar banner muncul di atas seluruh widget lain (bahkan di atas AppBar atau Peta):

```dart
void _showInAppNotificationBanner({
  required String senderId,
  required String senderName,
  required String messagePreview,
}) {
  if (!mounted) return;

  _notificationDismissTimer?.cancel();
  try {
    _currentNotificationOverlay?.remove();
  } catch (_) {}
  _currentNotificationOverlay = null;

  final overlay = Overlay.of(context);
  late final OverlayEntry entry;

  entry = OverlayEntry(
    builder: (context) {
      return Positioned(
        top: MediaQuery.of(context).padding.top + 8, // Tepat di bawah status bar HP
        left: 12,
        right: 12,
        child: Material(
          color: Colors.transparent,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: -60.0, end: 0.0), // Efek slide meluncur turun
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOutBack,
            builder: (context, value, child) {
              return Transform.translate(
                offset: Offset(0, value),
                child: child,
              );
            },
            child: InkWell(
              onTap: () {
                entry.remove();
                _currentNotificationOverlay = null;
                _openChatRoom(senderId); // Buka room chat langsung
              },
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E1E2C), // Latar gelap elegan
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                  border: Border.all(color: Colors.white24),
                ),
                child: Row(
                  children: [
                    const CircleAvatar(
                      radius: 20,
                      backgroundColor: Colors.blueAccent,
                      child: Icon(Icons.chat, color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  senderName,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade600,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  "PESAN BARU",
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            messagePreview,
                            style: const TextStyle(color: Colors.white70, fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white60, size: 18),
                      onPressed: () {
                        entry.remove();
                        _currentNotificationOverlay = null;
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );

  _currentNotificationOverlay = entry;
  overlay.insert(entry);

  // Otomatis tutup banner setelah 4 detik
  _notificationDismissTimer = Timer(const Duration(seconds: 4), () {
    if (_currentNotificationOverlay == entry) {
      entry.remove();
      _currentNotificationOverlay = null;
    }
  });
}
```

---

### Langkah 5: Tampilkan Badge Merah pada Kartu & Tombol Chat

Buat widget pembantu untuk menampilkan pil / lingkaran merah jika pesan belum dibaca > 0:

```dart
Widget _buildUnreadBadge(String targetUserId) {
  final count = _unreadCounts[targetUserId] ?? 0;
  if (count <= 0) return const SizedBox.shrink();

  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
    decoration: BoxDecoration(
      color: Colors.red.shade600,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Text(
      count > 99 ? '99+' : '$count Baru',
      style: const TextStyle(
        color: Colors.white,
        fontSize: 10,
        fontWeight: FontWeight.bold,
      ),
    ),
  );
}
```

Pasang badge di samping nama atau tombol:
```dart
Row(
  children: [
    Text(driver.name, style: TextStyle(fontWeight: FontWeight.bold)),
    const SizedBox(width: 8),
    _buildUnreadBadge(driver.id), // Badge merah otomatis muncul jika ada pesan
  ],
)
```

---

### Langkah 6: Tandai Pesan sebagai Terbaca saat Room Chat Dibuka

Di dalam `driver_chat_room_screen.dart`, panggil fungsi `markAllMessagesAsRead()` dari `ChatConversation`:

```dart
Future<void> _loadAgoraHistory() async {
  final conversation = await ChatClient.getInstance.chatManager
      .getConversation(widget.driverUserId, createIfNeed: true);

  if (conversation != null) {
    // 1. Tandai semua pesan percakapan ini sebagai terbaca di server Agora
    await conversation.markAllMessagesAsRead();
  }
  
  // 2. Muat riwayat pesan...
}
```

Saat pengguna kembali dari room chat ke dashboard utama:
```dart
void _openChatRoom(ShuttleUser user) async {
  await Navigator.push(context, MaterialPageRoute(builder: (_) => ChatScreen(user)));
  
  // Segera setelah kembali dari room chat, segarkan unread badge menjadi 0
  await _refreshUnreadCounts();
}
```

---

## 5. Panduan Praktis Demo Interaktif ke Atasan

Berikut skenario demonstrasi yang sangat menarik untuk diperlihatkan ke atasan:

1. **Skenario Penumpang Chat ke Driver:**
   * Di simulator/HP, pilih akun **Dadi M (Penumpang)**.
   * Buka *"Chat Driver"*, kirim pesan: *"Pak, saya sudah di depan lobi ya"*.
   * Ganti akun ke **Pak Dika (Driver)**.
   * Begitu masuk ke dashboard Driver, perhatikan:
     * Langsung muncul **Badge Merah `1 Baru`** di samping nama *Dadi M*.
     * Pada tombol *"Chat Penumpang"* muncul angka merah `1`.
2. **Skenario Banner Notifikasi Real-Time (Jika Pakai 2 HP):**
   * HP 1 (Driver) sedang berada di dashboard.
   * HP 2 (Penumpang) mengirim pesan chat.
   * **Seketika di HP 1 meluncur banner gelap dari atas layar:** *"Dadi M: Pak, posisi di mana?"*.
   * Atasan dapat melihat bahwa notifikasi bisa diklik langsung untuk menuju room chat!
3. **Skenario Tanya CS (Pusat Bantuan):**
   * Penumpang kirim chat ke CS.
   * Akun CS akan menerima banner notifikasi dan badge antrean secara instan.

---
*Dibuat untuk Tim Pengembang Sunjaya Shuttle Mobile Application.*

