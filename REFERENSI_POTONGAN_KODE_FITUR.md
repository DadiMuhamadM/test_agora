# 📖 Referensi Potongan Kode Fitur Utama Shuttle Chat

Panduan ringkas potongan kode fitur-fitur utama di aplikasi ini.

---

## 1. 🔔 Notifikasi Chat Masuk (Banner Melayang)

**File:** `lib/main.dart` → `_setupGlobalMessageAndCallListener()`

**Cara kerja:** Agora Chat SDK punya sistem **listener** — kita "dengerin" setiap pesan yang datang.

```dart
// Pasang listener global (dipanggil sekali saat app mulai)
ChatClient.getInstance.chatManager.addEventHandler(
  "GLOBAL_APP_HANDLER",       // ID unik listener
  ChatEventHandler(
    onMessagesReceived: (List<ChatMessage> messages) {
      // ↑ Callback ini otomatis dipanggil setiap ada pesan masuk

      for (var msg in messages) {
        // Ambil ID pengirim
        final senderId = msg.from ?? "";

        // Cek tipe pesan → buat teks preview
        if (msg.body.type == MessageType.TXT) {
          previewText = (msg.body as ChatTextMessageBody).content;
        } else if (msg.body.type == MessageType.IMAGE) {
          previewText = "📷 Mengirim sebuah foto";
        }

        // Jangan munculkan banner melayang jika pengguna sedang membuka room chat pengirim ini
        if (_activeChatUserId != null && _activeChatUserId == senderId) {
          continue;
        }

        // Update badge angka pesan belum dibaca
        _unreadCounts[senderId] = (_unreadCounts[senderId] ?? 0) + 1;

        // Tampilkan banner notifikasi melayang di atas layar
        _showInAppNotificationBanner(
          senderUser: senderUser,
          messagePreview: previewText,
        );
      }
    },
  ),
);
```

**Banner-nya sendiri** (`_showInAppNotificationBanner`) pakai `OverlayEntry` — widget yang "mengambang" di atas semua layar:

```dart
Timer? autoDismissTimer;

final entry = OverlayEntry(
  builder: (context) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 8, // Di bawah status bar
      left: 12, right: 12,
      child: InkWell(
        onTap: () {
          autoDismissTimer?.cancel();  // Batalkan timer auto-dismiss
          if (entry.mounted) entry.remove(); // Hapus hanya jika masih terpasang
          _openChatRoom(senderUser);   // Buka room chat pengirim
        },
        child: Container(/* ... tampilan banner ... */),
      ),
    );
  },
);

Overlay.of(context).insert(entry);     // Tampilkan ke layar

// Otomatis hilang setelah 4 detik (dengan pengecekan mounted)
autoDismissTimer = Timer(const Duration(seconds: 4), () {
  if (entry.mounted) {
    entry.remove();
  }
});
```

**Intinya:** Listener → dapat pesan → buat OverlayEntry → tampilkan → hilang otomatis 4 detik.

---

## 2. 📞 Notifikasi Telepon Masuk (Dialog Pop-up)

**File:** `lib/main.dart` → Masih di listener yang sama + `_showIncomingCallDialog()`

**Cara kerja:** Telepon di-"titipkan" lewat pesan chat biasa, tapi dengan **atribut khusus**.

### A. Sisi Penelepon — Kirim Sinyal Dering

```dart
// Buat pesan teks biasa
final callMsg = ChatMessage.createTxtSendMessage(
  targetId: "id-lawan-bicara",
  content: "📞 Panggilan Suara Masuk...",
);

// Tempelkan atribut khusus supaya penerima tahu ini telepon, bukan chat
callMsg.attributes = {
  "action": "CALL_INVITE",    // ← Penanda: ini undangan telepon!
  "channelId": "demo-channel",
  "isVideo": false,           // false = suara, true = video
  "callerName": "Pak Ibnu",
  "callTime": DateTime.now().millisecondsSinceEpoch, // ← Waktu kirim (mencegah dering kadaluarsa)
};

// Kirim
await ChatClient.getInstance.chatManager.sendMessage(callMsg);

// Buka layar telepon (Agora RTC)
Navigator.push(context, MaterialPageRoute(
  builder: (_) => CallScreen(channelId: channelId, isVideoCall: false),
));
```

### B. Sisi Penerima — Deteksi & Tampilkan Dialog

```dart
// Masih di dalam onMessagesReceived...
if (msg.attributes != null && msg.attributes!["action"] == "CALL_INVITE") {
  // 1. Cek batas kadaluarsa panggilan (maksimal 35 detik)
  // Mencegah pesan lama (offline message) memicu pop-up saat baru buka aplikasi!
  final callTime = (msg.attributes!["callTime"] as int?) ??
      (msg.serverTime > 0 ? msg.serverTime : msg.localTime);
  if (callTime > 0) {
    final ageInSeconds = (DateTime.now().millisecondsSinceEpoch - callTime) / 1000;
    if (ageInSeconds > 35) {
      continue; // Abaikan jika panggilan sudah lewat dari 35 detik yang lalu
    }
  }

  // 2. Ambil data panggilan
  final channelId = msg.attributes!["channelId"] as String;
  final isVideo = msg.attributes!["isVideo"] as bool;

  // 3. Tampilkan dialog pop-up "Ada Telepon Masuk"
  _showIncomingCallDialog(
    caller: callerName,
    channelId: channelId,
    isVideo: isVideo,
  );
  continue; // 👈 WAJIB: memotong loop agar tidak memunculkan notif chat biasa!
}
```

**Dialog-nya** pakai `showDialog` biasa dengan tombol **Tolak** dan **Terima**:

```dart
showDialog(
  barrierDismissible: false,   // Tidak bisa ditutup klik di luar
  builder: (ctx) => Dialog(
    child: Column(
      children: [
        // Icon & Judul
        Icon(isVideo ? Icons.videocam : Icons.phone_in_talk),
        Text("Panggilan dari $caller"),

        // Tombol Tolak & Terima
        Row(
          children: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text("Tolak")),
            ElevatedButton(
              onPressed: () {
                Navigator.pushReplacement(ctx, MaterialPageRoute(
                  builder: (_) => CallScreen(channelId: channelId),
                ));
              },
              child: Text("Terima"),
            ),
          ],
        ),
      ],
    ),
  ),
);
```

**Intinya:** Kirim chat biasa + atribut `"action":"CALL_INVITE"` → penerima cek atribut → tampilkan dialog → terima/tolak.

---

## 3. 📷 Kirim Gambar / Foto

**File:** `lib/driver_chat_room_screen.dart` → `_pickAndSendImage()`

**Cara kerja:** Pilih foto → Agora otomatis upload ke CDN mereka → penerima dapat URL-nya.

```dart
// 1. Buka galeri/kamera pakai image_picker
final pickedFile = await _picker.pickImage(
  source: source,          // ImageSource.gallery atau ImageSource.camera
  imageQuality: 75,        // Kompres 75% supaya hemat kuota
  maxWidth: 1280,
  maxHeight: 1280,
);
if (pickedFile == null) return; // User batal

// 2. Buat pesan gambar Agora
final msg = ChatMessage.createImageSendMessage(
  targetId: widget.driverUserId,  // ID penerima
  filePath: pickedFile.path,      // Path file di HP
  displayName: pickedFile.name,   // Nama file
  sendOriginalImage: false,       // false = pakai kompresi Agora
);

// 3. Kirim — Agora otomatis upload gambar ke cloud CDN mereka
await ChatClient.getInstance.chatManager.sendMessage(msg);

// 4. Tampilkan di chat lokal (Optimistic UI — langsung tampil tanpa nunggu)
setState(() {
  _messages.add(ShuttleChatMessage(
    type: ShuttleMessageType.image,
    text: pickedFile.name,
    isMe: true,
    time: DateTime.now(),
    localPath: pickedFile.path,
  ));
});
```

**Sisi penerima** (di listener `onMessagesReceived`):

```dart
if (msg.body.type == MessageType.IMAGE) {
  final body = msg.body as ChatImageMessageBody;
  
  // Prioritaskan file lokal (agar instan tanpa lag & aman dari auth CDN)
  String? validLocalPath;
  if (body.localPath != null && File(body.localPath!).existsSync()) {
    validLocalPath = body.localPath;
  } else if (body.thumbnailLocalPath != null && File(body.thumbnailLocalPath!).existsSync()) {
    validLocalPath = body.thumbnailLocalPath;
  }

  _messages.add(ShuttleChatMessage(
    type: ShuttleMessageType.image,
    text: body.displayName ?? '',
    isMe: false,
    time: DateTime.fromMillisecondsSinceEpoch(timestamp),
    localPath: validLocalPath, // 👈 Pakai lokal jika ada, atau fallback ke CDN URL
    remoteUrl: body.remotePath,
    thumbnailUrl: body.thumbnailRemotePath,
  ));
}
```

**Tampilan Widget Gambar (`_buildImageContent`)**:
Prioritaskan `Image.file(File(localPath))` sebelum beralih ke `Image.network(remoteUrl)`.

**Intinya:** `createImageSendMessage()` → `sendMessage()` → Agora upload ke CDN → penerima dapat URL via `remotePath`.

---

## 4. 💬 Kirim Pesan Teks

**File:** `lib/driver_chat_room_screen.dart` → `_send()`

Yang paling sederhana — 3 baris inti saja:

```dart
// 1. Buat pesan teks
final msg = ChatMessage.createTxtSendMessage(
  targetId: widget.driverUserId,  // ID penerima
  content: text,                  // Isi pesan
);

// 2. Kirim ke server Agora
await ChatClient.getInstance.chatManager.sendMessage(msg);

// 3. Tampilkan di UI lokal
setState(() {
  _messages.add(ShuttleChatMessage(text: text, isMe: true, time: DateTime.now()));
});
```

---

## 5. 📥 Inbox Dinamis CS (Kotak Masuk)

**File:** `lib/main.dart` → `_loadCsConversations()`

```dart
// 1. Muat semua percakapan yang tersimpan di database lokal Agora
final convs = await ChatClient.getInstance.chatManager.loadAllConversations();

// 2. Filter: hanya yang punya pesan (bukan percakapan kosong)
for (final conv in convs) {
  final latest = await conv.latestMessage();
  if (latest != null) {
    activeConvs.add(conv);              // Masukkan ke list
    lastMsgs[conv.id] = "...snippet";   // Simpan cuplikan pesan terakhir
  }
}

// 3. Update tampilan
setState(() {
  _csConversations = activeConvs;
  _lastMessages = lastMsgs;
});
```

**Kapan dipanggil?**
- Saat CS login (`_loginAgora`)
- Saat ada pesan masuk real-time (`onMessagesReceived`)
- Saat CS kembali dari room chat (`_openChatRoom`)
- Saat CS tekan tombol refresh manual

---

## 6. 🗑️ Hapus Percakapan

**File:** `lib/main.dart` → `_deleteCsConversation()`

```dart
// Satu baris inti:
await ChatClient.getInstance.chatManager.deleteConversation(
  conversationId,          // ID lawan bicara
  deleteMessages: true,    // true = hapus semua riwayat pesan juga
);
```

---

## 7. ⏱️ Waktu Chat & Ceklis Biru WhatsApp (Read Receipts)

**File:** `lib/driver_chat_room_screen.dart` → `_buildMessageStatus()` & `_sendReadAck()`

**Cara kerja:**
1. Di bawah balon pesan selalu ditampilkan waktu pengiriman: `_formatTime(msg.time)` (contoh: `14:25`).
2. Untuk pesan yang kita kirim (`isMe == true`), tanda ceklis berubah dinamis seperti WhatsApp:
   - **Ceklis 1 Abu-abu (`Icons.done`)**: Pesan terkirim ke server Agora.
   - **Ceklis 2 Abu-abu (`Icons.done_all`, white70)**: Pesan sudah tersampaikan ke perangkat penerima (`hasDeliverAck`).
   - **Ceklis 2 Biru (`Icons.done_all`, Color(0xFF00E5FF))**: Pesan **sudah dibuka & dibaca** oleh lawan bicara (`hasReadAck`).

### A. Sisi Penerima — Mengirim Tanda "Sudah Dibaca" (Read Ack)
Saat user membuka room chat lawan bicara, panggil `sendConversationReadAck`:
```dart
// Tandai pesan terbaca lokal & kirim sinyal ke server bahwa kita sudah baca
await conv?.markAllMessagesAsRead();
await ChatClient.getInstance.chatManager.sendConversationReadAck(widget.driverUserId);
```

### B. Sisi Pengirim — Menerima Notifikasi "Sudah Dibaca" & Ubah Ceklis Jadi Biru
Di dalam `ChatEventHandler`:
```dart
onConversationRead: (String from, String to) {
  // Lawan bicara telah membaca percakapan kita!
  setState(() {
    for (var m in _messages) {
      if (m.isMe) m.isRead = true; // 👈 Ubah semua ceklis jadi biru!
    }
  });
},
```

### C. Tampilan Widget Ceklis & Waktu
```dart
Widget _buildMessageStatus(ShuttleChatMessage msg) {
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(_formatTime(msg.time)), // Waktu di bawah pesan
      if (msg.isMe) ...[
        const SizedBox(width: 4),
        if (msg.isRead)
          const Icon(Icons.done_all, color: Color(0xFF00E5FF)) // 🔵 Biru WhatsApp
        else if (msg.isDelivered)
          const Icon(Icons.done_all, color: Colors.white70)     // ⚪ Ceklis 2 abu
        else
          const Icon(Icons.done, color: Colors.white70),        // ⚪ Ceklis 1
      ],
    ],
  );
}
```

---

## Ringkasan Alur Keseluruhan

```
┌─────────────┐    Agora Chat SDK     ┌─────────────┐
│  Pengirim   │ ───────────────────►  │  Penerima   │
│             │                        │             │
│ createTxt.. │  Server Agora mengi-   │ onMessages  │
│ createImage │  rim pesan ke HP       │ Received()  │
│ sendMessage │  penerima              │             │
└─────────────┘                        └──────┬──────┘
                                              │
                                    ┌─────────┴─────────┐
                                    │ Cek tipe pesan:    │
                                    │                    │
                                    │ attributes         │
                                    │ "CALL_INVITE"?     │
                                    │  → Dialog Telepon  │
                                    │                    │
                                    │ body.type == TXT?  │
                                    │  → Banner Notif    │
                                    │                    │
                                    │ body.type == IMAGE? │
                                    │  → Banner + Foto   │
                                    └────────────────────┘
```

