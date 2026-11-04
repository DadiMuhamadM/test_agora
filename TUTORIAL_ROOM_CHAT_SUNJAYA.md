# 📱 Tutorial Room Chat SISI CUSTOMER (Aplikasi Penumpang Sunjaya Mobile)

Panduan ini dibuat khusus untuk **Aplikasi Customer / Penumpang (`sunjaya_mobile`)**.
Layar ini digunakan oleh **Penumpang** untuk melihat status driver, mengirim pesan chat, serta melakukan panggilan telepon langsung ke **Driver Shuttle** yang ditugaskan menjemputnya.

> [!CAUTION]
> ### ⚠️ PENTING: MENGATASI ERROR `MissingPluginException` (`com.chat.im`)
> Jika muncul pesan: **`MissingPluginException: No implementation found for method sendMessage on channel com.chat.im`**, hal ini terjadi karena 2 hal:
> 1. **Aplikasi HANYA di-Hot Reload / Hot Restart**:
>    Package baru yang memiliki kode *native* Android/C++ (`agora_chat_sdk`) **TIDAK BISA** langsung berjalan lewat Hot Reload.
>    **Solusi Wajib:**
>    * Hentikan (*Stop*) aplikasi Flutter yang sedang berjalan.
>    * **Uninstall (Hapus)** aplikasi Sunjaya lama dari HP Android Anda.
>    * Jalankan perintah di terminal proyek Anda:
>      ```bash
>      flutter clean
>      flutter pub get
>      flutter run
>      ```
> 2. **Agora Chat SDK Belum Diinisialisasi (`init`) dan Belum Login (`loginWithToken`)**:
>    SDK Agora Chat wajib diinisialisasi sebelum fungsi kirim/muat pesan dipanggil. Di versi terbaru ini, `ChatDriverScreen` sudah dilengkapi **Auto-Inisialisasi & Auto-Login otomatis** di fungsi `initState()`.

---

## 📌 PANDUAN COPY-PASTE BERTAHAP
Anda dapat menyalin (*copy-paste*) kode di bawah ini potongan demi potongan ke proyek `sunjaya_mobile` Anda:

1. [Potongan 1: Package di `pubspec.yaml`, Gradle, & Warna](#potongan-1-package-di-pubspecyaml-gradle--warna)
2. [Potongan 2: Model Pesan (`ShuttleChatMessage`)](#potongan-2-model-pesan-shuttlechatmessage)
3. [Potongan 3: Kerangka `ChatDriverScreen`](#potongan-3-kerangka-chatdriverscreen)
4. [Potongan 4: Inisialisasi Otomatis, State, & Siklus Hidup](#potongan-4-inisialisasi-otomatis-state--siklus-hidup)
5. [Potongan 5: Muat Riwayat Chat dari Agora (`_loadAgoraHistory`)](#potongan-5-muat-riwayat-chat-dari-agora-_loadagorahistory)
6. [Potongan 6: Listener Pesan & Telepon Masuk dari Driver (`_setupAgoraListener`)](#potongan-6-listener-pesan--telepon-masuk-dari-driver-_setupagoralistener)
7. [Potongan 7: Fungsi Kirim Pesan ke Driver (`_send`)](#potongan-7-fungsi-kirim-pesan-ke-driver-_send)
8. [Potongan 8: Customer Menelepon Driver (`_startCall`) & Pop-up Panggilan Masuk](#potongan-8-customer-menelepon-driver-_startcall--pop-up-panggilan-masuk)
9. [Potongan 9: Tampilan AppBar (Profil Driver & Tombol Telepon)](#potongan-9-tampilan-appbar-profil-driver--tombol-telepon)
10. [Potongan 10: Tampilan Daftar Pesan & Balon Chat (`_buildBubble`)](#potongan-10-tampilan-daftar-pesan--balon-chat-_buildbubble)
11. [Potongan 11: Quick Replies & Kolom Tulis Pesan](#potongan-11-quick-replies--kolom-tulis-pesan)
12. [Potongan 12: Cara Buka Layar dari Layar Pelacakan Shuttle](#potongan-12-cara-buka-layar-dari-layar-pelacakan-shuttle)

---

## Potongan 1: Package di `pubspec.yaml`, Gradle, & Warna

### 1.1 File `pubspec.yaml`
Pastikan SDK Agora Chat & RTC sudah terdaftar di `sunjaya_mobile/pubspec.yaml`:
```yaml
dependencies:
  flutter:
    sdk: flutter
  agora_chat_sdk: ^1.4.0+1   # Untuk bertukar pesan chat teks & foto
  agora_rtc_engine: ^6.6.4   # Untuk voice call & video call dengan driver
  permission_handler: 11.3.1 # Izin mikrofon & kamera HP
```

### 1.2 Konfigurasi Gradle Android (`libaosl.so` Konflik Prevention)
Karena `agora_chat_sdk` dan `agora_rtc_engine` sama-sama memuat pustaka native `libaosl.so`, tambahkan baris berikut di `android/app/build.gradle` agar build tidak gagal:

**Jika menggunakan `android/app/build.gradle` (Groovy):**
```groovy
android {
    ...
    packagingOptions {
        pickFirst '**/libaosl.so'
    }
}
```

**Jika menggunakan `android/app/build.gradle.kts` (Kotlin DSL):**
```kotlin
android {
    ...
    packaging {
        jniLibs {
            pickFirsts += listOf("**/libaosl.so")
        }
    }
}
```

### 1.3 File `lib/core/res/colors.dart`
Pastikan warna tema aplikasi Anda tersedia:
```dart
class COLORS {
  static const Color primary = Color(0xFF0066FF); // Warna branding Sunjaya Shuttle
}
```

---

## Potongan 2: Model Pesan (`ShuttleChatMessage`)

Buat file baru di proyek Anda: `lib/features/chat/chat_driver_screen.dart`.
Salin import dan model data berikut di bagian paling atas:

```dart
import 'package:agora_chat_sdk/agora_chat_sdk.dart';
import 'package:flutter/material.dart';
import 'package:sunjaya_mobile/core/res/colors.dart'; // Sesuaikan path warna Anda
// import 'package:sunjaya_mobile/call_screen.dart';   // Layar panggilan RTC jika sudah dibuat

/// Model pesan obrolan sisi Customer
class ShuttleChatMessage {
  final String text;      // Isi teks pesan
  final bool isMe;        // true = Customer (kita sendiri), false = Driver Shuttle
  final DateTime time;    // Waktu pengiriman

  ShuttleChatMessage({
    required this.text,
    required this.isMe,
    required this.time,
  });
}
```

> [!NOTE]
> **Penjelasan Logika:**
> * `isMe = true`: Pesan dikirim oleh **Customer** (akan tampil di sisi kanan dengan warna tema `COLORS.primary`).
> * `isMe = false`: Pesan balasan dari **Driver** (akan tampil di sisi kiri dengan latar putih/abu-abu).

---

## Potongan 3: Kerangka `ChatDriverScreen`

Salin kerangka StatefulWidget ini di bawah model pesan:

```dart
class ChatDriverScreen extends StatefulWidget {
  final String driverName;      // Nama Driver yang menjemput (contoh: "Pak Dika")
  final String driverUserId;    // ID Agora Driver (contoh: "dhika-driver")
  final String customerUserId;  // ID Agora Customer yang sedang login (contoh: "dhadi-cust")
  final String customerToken;   // Token Agora Customer untuk otentikasi
  final String appKey;          // App Key Agora Chat proyek Anda

  const ChatDriverScreen({
    super.key,
    required this.driverName,
    required this.driverUserId,
    required this.customerUserId,
    this.customerToken = "ISI_DENGAN_TOKEN_CUSTOMER_AGORA",
    this.appKey = "61200084352#200118764", // Ganti dengan AppKey Agora Anda
  });

  @override
  State<ChatDriverScreen> createState() => _ChatDriverScreenState();
}
```

**Penjelasan Parameter:**
* `driverName`: Nama driver yang tampil di AppBar.
* `driverUserId`: Target pengiriman pesan ke driver di server Agora.
* `customerUserId`: ID user customer yang login di aplikasi Sunjaya.
* `customerToken`: Token RTC/Chat customer untuk otentikasi ke Agora.
* `appKey`: Kunci aplikasi Agora Chat Anda.

---

## Potongan 4: Inisialisasi Otomatis, State, & Siklus Hidup

Salin deklarasi state, auto-inisialisasi Agora, dan *lifecycle* ini:

```dart
class _ChatDriverScreenState extends State<ChatDriverScreen> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  // Template balasan cepat khusus penumpang untuk mempercepat komunikasi penjemputan
  static const List<String> _quickReplies = [
    'Saya sudah di lokasi jemput',
    'Saya di depan lobi utama',
    'Posisi bapak sudah sampai mana?',
    'Mohon tunggu sebentar',
    'Terima kasih pak',
  ];

  // List yang menampung daftar balon chat di layar customer
  final List<ShuttleChatMessage> _messages = [];
  bool _isInitializing = true;

  @override
  void initState() {
    super.initState();
    // Inisialisasi SDK, login, muat riwayat obrolan, dan pasang listener
    _initAgoraAndHistory();
  }

  // ==========================================================================
  // INISIALISASI OTOMATIS & LOGIN KE AGORA CHAT
  // ==========================================================================
  Future<void> _initAgoraAndHistory() async {
    await _ensureAgoraInitializedAndLoggedIn();
    await _loadAgoraHistory();
    _setupAgoraListener();
    if (mounted) {
      setState(() {
        _isInitializing = false;
      });
    }
  }

  Future<void> _ensureAgoraInitializedAndLoggedIn() async {
    try {
      debugPrint("[CUSTOMER CHAT] 🚀 Memeriksa inisialisasi Agora Chat SDK...");
      ChatOptions options = ChatOptions.withAppKey(
        widget.appKey,
        autoLogin: false,
      );
      await ChatClient.getInstance.init(options);
      await ChatClient.getInstance.startCallback();

      final current = ChatClient.getInstance.currentUserId;
      if (current != widget.customerUserId) {
        debugPrint("[CUSTOMER CHAT] 🔐 Login Agora sebagai ${widget.customerUserId}...");
        try {
          await ChatClient.getInstance.logout(true);
        } catch (_) {}
        await ChatClient.getInstance.loginWithToken(
          widget.customerUserId,
          widget.customerToken,
        );
        debugPrint("[CUSTOMER CHAT] ✅ Berhasil login ke Agora Chat!");
      } else {
        debugPrint("[CUSTOMER CHAT] ✅ Sesi aktif terdeteksi (${widget.customerUserId})");
      }
    } catch (e) {
      debugPrint("[CUSTOMER CHAT] ⚠️ Inisialisasi/Login Agora Chat: $e");
    }
  }

  @override
  void dispose() {
    // Wajib: Hapus listener saat customer keluar dari room chat agar RAM tidak bocor!
    ChatClient.getInstance.chatManager.removeEventHandler("CUSTOMER_ROOM_CHAT_HANDLER");
    _controller.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }
```

---

## Potongan 5: Muat Riwayat Chat dari Agora (`_loadAgoraHistory`)

Salin fungsi ini ke dalam state:

```dart
  Future<void> _loadAgoraHistory() async {
    try {
      // 1. Ambil atau buat objek percakapan dengan Driver
      final conversation = await ChatClient.getInstance.chatManager.getConversation(
        widget.driverUserId,
        createIfNeed: true,
      );

      List<ChatMessage> list = [];

      // 2. Ambil dari database lokal di HP terlebih dahulu
      if (conversation != null) {
        list = await conversation.loadMessages(
          loadCount: 50,
          direction: ChatSearchDirection.Up,
        );
      }

      // 3. Jika database lokal masih kosong, ambil dari Server Agora (Roaming Messages)
      if (list.isEmpty) {
        try {
          final result = await ChatClient.getInstance.chatManager.fetchHistoryMessagesByOption(
            widget.driverUserId,
            ChatConversationType.Chat,
            options: FetchMessageOptions(
              direction: ChatSearchDirection.Up,
              needSave: true, // Simpan ke lokal agar selanjutnya cepat
            ),
            pageSize: 50,
          );
          list = result.data;
        } catch (serverErr) {
          debugPrint("[CUSTOMER CHAT] Fetch riwayat server: $serverErr");
        }
      }

      // 4. Urutkan secara kronologis dari terlama ke terbaru
      list.sort((a, b) {
        final tA = a.serverTime > 0 ? a.serverTime : a.localTime;
        final tB = b.serverTime > 0 ? b.serverTime : b.localTime;
        return tA.compareTo(tB);
      });

      List<ShuttleChatMessage> history = [];
      for (var msg in list) {
        if (msg.body.type == MessageType.TXT) {
          // Saring metadata panggilan telepon agar tidak muncul sebagai balon chat teks
          if (msg.attributes != null && msg.attributes!["action"] == "CALL_INVITE") {
            continue;
          }
          final body = msg.body as ChatTextMessageBody;
          // Jika pengirim adalah customerUserId, berarti dikirim oleh Customer (isMe = true)
          final isMe = msg.from == widget.customerUserId;
          final timestamp = msg.serverTime > 0 ? msg.serverTime : msg.localTime;

          history.add(
            ShuttleChatMessage(
              text: body.content,
              isMe: isMe,
              time: DateTime.fromMillisecondsSinceEpoch(timestamp),
            ),
          );
        }
      }

      if (mounted) {
        setState(() {
          _messages.clear();
          _messages.addAll(history);
        });
        _scrollToBottom();
      }
    } catch (e) {
      debugPrint("[CUSTOMER CHAT] Gagal memuat riwayat: $e");
    }
  }
```

---

## Potongan 6: Listener Pesan & Telepon Masuk dari Driver (`_setupAgoraListener`)

Salin fungsi penerima pesan ini:

```dart
  void _setupAgoraListener() {
    debugPrint("[CUSTOMER CHAT] 🎧 Memasang listener pesan real-time...");
    ChatClient.getInstance.chatManager.addEventHandler(
      "CUSTOMER_ROOM_CHAT_HANDLER",
      ChatEventHandler(
        onMessagesReceived: (List<ChatMessage> messages) {
          debugPrint("[CUSTOMER CHAT] 📩 Pesan baru diterima: ${messages.length} pesan");
          for (var msg in messages) {
            final sender = msg.from?.trim().toLowerCase();
            final expectedSender = widget.driverUserId.trim().toLowerCase();

            // Pastikan pesan berasal dari driver yang sedang kita buka chatnya
            if (sender == expectedSender) {
              
              // 1. Jika Driver sedang menelepon Customer (sinyal CALL_INVITE)
              if (msg.attributes != null && msg.attributes!["action"] == "CALL_INVITE") {
                final channelId = msg.attributes!["channelId"] as String? ?? "shuttle_call";
                final isVideo = msg.attributes!["isVideo"] as bool? ?? false;
                _showIncomingCallDialog(
                  caller: widget.driverName,
                  channelId: channelId,
                  isVideo: isVideo,
                );
                continue;
              }

              // 2. Jika Driver membalas pesan teks biasa
              if (msg.body.type == MessageType.TXT) {
                final body = msg.body as ChatTextMessageBody;
                final timestamp = msg.serverTime > 0
                    ? msg.serverTime
                    : (msg.localTime > 0
                        ? msg.localTime
                        : DateTime.now().millisecondsSinceEpoch);

                debugPrint("[CUSTOMER CHAT] 💬 Pesan baru masuk real-time: \"${body.content}\"");

                if (mounted) {
                  setState(() {
                    _messages.add(
                      ShuttleChatMessage(
                        text: body.content,
                        isMe: false, // false = Pesan balasan dari driver
                        time: DateTime.fromMillisecondsSinceEpoch(timestamp),
                      ),
                    );
                  });
                  _scrollToBottom();
                }
              }
            }
          }
        },
      ),
    );
  }
```

---

## Potongan 7: Fungsi Kirim Pesan ke Driver (`_send`)

Salin fungsi kirim pesan teks, kontrol tombol quick reply, dan format waktu:

```dart
  // Customer mengirim pesan teks ke Driver
  Future<void> _send([String? quickText]) async {
    final text = (quickText ?? _controller.text).trim();
    if (text.isEmpty) return;

    // Buat pesan teks dengan target driverUserId
    final msg = ChatMessage.createTxtSendMessage(
      targetId: widget.driverUserId,
      content: text,
    );

    try {
      await ChatClient.getInstance.chatManager.sendMessage(msg);

      if (mounted) {
        setState(() {
          _messages.add(
            ShuttleChatMessage(
              text: text,
              isMe: true, // true = Dikirim oleh customer
              time: DateTime.now(),
            ),
          );
        });
        _controller.clear();
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Gagal mengirim pesan: $e")),
        );
      }
    }
  }

  // Mengisi teks dari tombol balasan cepat (Quick Reply)
  void _fillQuickReply(String text) {
    _controller.text = text;
    _controller.selection = TextSelection.fromPosition(
      TextPosition(offset: text.length),
    );
    _focusNode.requestFocus();
  }

  // Menggulung chat ke bawah otomatis
  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  // Format jam menit 2 digit (HH:mm)
  String _formatTime(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
```

---

## Potongan 8: Customer Menelepon Driver (`_startCall`) & Pop-up Panggilan Masuk

Salin fungsi panggilan suara & video:

```dart
  // Customer menelepon Driver Shuttle
  Future<void> _startCall({required bool isVideo}) async {
    final channelId = "shuttle_${widget.customerUserId}_${widget.driverUserId}";

    // 1. Kirim sinyal dering ke HP Driver via Agora Chat
    final callMsg = ChatMessage.createTxtSendMessage(
      targetId: widget.driverUserId,
      content: isVideo ? "📹 Panggilan Video Masuk..." : "📞 Panggilan Suara Masuk...",
    );
    callMsg.attributes = {
      "action": "CALL_INVITE",
      "channelId": channelId,
      "isVideo": isVideo,
      "caller": widget.customerUserId,
    };

    try {
      await ChatClient.getInstance.chatManager.sendMessage(callMsg);
    } catch (e) {
      debugPrint("[CUSTOMER CALL] Gagal kirim sinyal telepon: $e");
    }

    // 2. Buka Layar CallScreen di HP Customer
    if (mounted) {
      // Pastikan file call_screen.dart sudah diimport
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CallScreen(
            channelId: channelId,
            isVideoCall: isVideo,
            targetName: widget.driverName,
          ),
        ),
      );
    }
  }

  // Pop-up dialog jika Driver menelepon Customer saat sedang di room chat
  void _showIncomingCallDialog({
    required String caller,
    required String channelId,
    required bool isVideo,
  }) {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: const Color(0xFF1E1E2C),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 36,
                  backgroundColor: isVideo ? Colors.blue.shade700 : Colors.green.shade700,
                  child: Icon(
                    isVideo ? Icons.videocam : Icons.phone_in_talk,
                    size: 38,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  isVideo ? "Panggilan Video dari Driver" : "Panggilan Suara dari Driver",
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 6),
                Text(
                  caller,
                  style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  "Driver sedang menghubungi Anda mengenai penjemputan.",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white54, fontSize: 12),
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        backgroundColor: Colors.red.shade700,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () => Navigator.of(dialogContext).pop(),
                      icon: const Icon(Icons.call_end),
                      label: const Text("Tolak"),
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade600,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        Navigator.of(dialogContext).pop();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => CallScreen(
                              channelId: channelId,
                              isVideoCall: isVideo,
                              targetName: caller,
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.call),
                      label: const Text("Terima"),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
```

---

## Potongan 9: Tampilan AppBar (Profil Driver & Tombol Telepon)

Salin fungsi `build()` utama dan `_buildAppBar()`:

```dart
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: _buildAppBar(context),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(child: _buildMessageList()), // Balon-balon chat
            _buildQuickReplies(),                 // Template balasan cepat
            _buildInputBar(),                     // Kolom ketik pesan
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0.5,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.black87),
        onPressed: () => Navigator.pop(context),
      ),
      titleSpacing: 0,
      title: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: COLORS.primary.withValues(alpha: 0.1),
            child: const Icon(Icons.person, color: COLORS.primary, size: 22),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.driverName, // Menampilkan Nama Driver Shuttle
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: Colors.black87),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'Driver Shuttle • Online',
                      style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          tooltip: "Telepon Driver",
          onPressed: () => _startCall(isVideo: false),
          icon: const Icon(Icons.phone, color: COLORS.primary),
        ),
        IconButton(
          tooltip: "Video Call Driver",
          onPressed: () => _startCall(isVideo: true),
          icon: const Icon(Icons.videocam, color: COLORS.primary),
        ),
        const SizedBox(width: 8),
      ],
    );
  }
```

---

## Potongan 10: Tampilan Daftar Pesan & Balon Chat (`_buildBubble`)

Salin widget daftar pesan dan styling gelembung chat:

```dart
  Widget _buildMessageList() {
    if (_isInitializing) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(strokeWidth: 2.5),
            SizedBox(height: 12),
            Text(
              'Menghubungkan ke server chat...',
              style: TextStyle(color: Colors.grey, fontSize: 13),
            ),
          ],
        ),
      );
    }

    if (_messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.chat_bubble_outline, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 12),
            Text(
              'Belum ada pesan dengan driver.\nTanyakan posisi driver atau konfirmasi titik jemput Anda.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[500], fontSize: 13),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: _messages.length,
      itemBuilder: (context, i) => _buildBubble(_messages[i]),
    );
  }

  Widget _buildBubble(ShuttleChatMessage msg) {
    final isMe = msg.isMe; // true = Customer kita, false = Driver

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.72,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isMe ? COLORS.primary : Colors.white, // Kanan biru (Customer), Kiri putih (Driver)
          border: isMe ? null : Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMe ? 16 : 3),
            bottomRight: Radius.circular(isMe ? 3 : 16),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                msg.text,
                style: TextStyle(
                  color: isMe ? Colors.white : const Color(0xFF1F2937),
                  fontSize: 14,
                  height: 1.3,
                ),
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _formatTime(msg.time),
                  style: TextStyle(
                    fontSize: 10,
                    color: isMe ? Colors.white70 : Colors.grey[500],
                  ),
                ),
                if (isMe) ...[
                  const SizedBox(width: 4),
                  const Icon(Icons.done_all, size: 13, color: Colors.white70),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
```

---

## Potongan 11: Quick Replies & Kolom Tulis Pesan

Salin widget balasan cepat dan textfield input:

```dart
  Widget _buildQuickReplies() {
    return Container(
      color: Colors.transparent,
      height: 44,
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _quickReplies.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          return ActionChip(
            label: Text(
              _quickReplies[i],
              style: const TextStyle(fontSize: 12, color: COLORS.primary),
            ),
            backgroundColor: Colors.white,
            side: const BorderSide(color: COLORS.primary),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            onPressed: () => _fillQuickReply(_quickReplies[i]),
          );
        },
      ),
    );
  }

  Widget _buildInputBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              minLines: 1,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              onSubmitted: (_) => _send(),
              decoration: InputDecoration(
                hintText: 'Tulis pesan untuk driver...',
                hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
                filled: true,
                fillColor: const Color(0xFFF3F4F6),
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          InkWell(
            onTap: _send,
            borderRadius: BorderRadius.circular(24),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                color: COLORS.primary,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.send, color: Colors.white, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}
```

---

## Potongan 12: Cara Buka Layar dari Layar Pelacakan Shuttle

Di layar aplikasi customer mana pun (misalnya di `LokasiDriverScreen` atau di kartu detail penjemputan shuttle):

```dart
// Buka room chat dengan driver saat tombol ditekan
ElevatedButton.icon(
  style: ElevatedButton.styleFrom(
    backgroundColor: COLORS.primary,
    foregroundColor: Colors.white,
    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
  ),
  onPressed: () {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const ChatDriverScreen(
          driverName: "Pak Dika (Shuttle Sunjaya)", // Nama Driver dari API booking
          driverUserId: "dhika-driver",             // ID Agora Driver dari backend
          customerUserId: "dhadi-cust",             // ID Agora Customer kita sendiri
          customerToken: "TOKEN_AGORA_CUSTOMER",    // Token Agora Chat milik Customer
          appKey: "61200084352#200118764",          // AppKey Agora Chat Anda
        ),
      ),
    );
  },
  icon: const Icon(Icons.chat_bubble_outline),
  label: const Text("Hubungi Driver"),
)
```

Selesai! Dengan panduan potongan di atas, aplikasi **`sunjaya_mobile`** Anda kini memiliki Room Chat sisi Customer yang siap digunakan, aman, dan mudah di-maintain. 🚀