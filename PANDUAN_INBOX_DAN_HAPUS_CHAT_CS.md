# 📋 Panduan Implementasi: Kotak Masuk Dinamis & Fitur Hapus Chat Customer Service (CS)

Dokumen ini menjelaskan arsitektur, cara kerja, dan panduan langkah demi langkah implementasi **Inbox Percakapan Dinamis** serta **Fitur Hapus Riwayat Chat** pada sisi Customer Service (Helpdesk) menggunakan **Agora Chat SDK** di aplikasi Flutter Shuttle (`sunjaya_mobile`).

---

## 🎯 1. Latar Belakang & Konsep

Pada sistem simulasi sebelumnya, dashboard CS menampilkan daftar seluruh penumpang (_hardcoded_ list 2 penumpang). Namun, pada aplikasi chat _real-world_ (seperti WhatsApp Business, Zendesk, atau Freshchat):

1. **Inbox Awal Kosong**: Ketika CS baru _login_ atau belum ada pelanggan/driver yang mengirim pesan, daftar tiket obrolan **kosong (_Empty State_)**.
2. **Otomatis Muncul saat Ada Pesan Masuk**: Ketika pelanggan (misal: Oding) mengirim chat atau foto ke CS, obrolan tersebut secara otomatis masuk ke antrean inbox CS lengkap dengan cuplikan pesan terakhir dan _badge_ unread.
3. **Penyelesaian Masalah & Hapus Riwayat**: Setelah CS selesai melayani kebutuhan pelanggan (masalah tiket terselesaikan), CS dapat **menyelesaikan dan menghapus riwayat obrolan (_delete conversation_)** agar antrean CS tetap bersih dan terorganisir.
4. **Chat Proaktif**: Jika CS perlu menghubungi driver armada atau penumpang terlebih dahulu tanpa menunggu mereka mengirim chat duluan, CS disediakan tombol inisiasi chat cepat.

---

## ⚙️ 2. Cara Kerja API Agora Chat SDK

Fitur ini memanfaatkan API bawaan **Agora Chat SDK (`agora_chat_sdk`)**:

### A. Memuat Daftar Percakapan Aktif (`loadAllConversations`)

Agora Chat SDK secara otomatis menyimpan percakapan yang pernah terjadi di dalam basis data lokal perangkat (_encrypted SQLite_).

```dart
// Memuat seluruh percakapan yang tersimpan di Agora SDK
final List<ChatConversation> convs =
    await ChatClient.getInstance.chatManager.loadAllConversations();
```

### B. Memeriksa Pesan Terakhir (`latestMessage`)

Untuk memastikan hanya percakapan yang benar-benar memiliki riwayat obrolan yang ditampilkan di inbox:

```dart
final ChatMessage? latest = await conv.latestMessage();
if (latest != null) {
  // Percakapan aktif: ambil teks atau indikator foto
  if (latest.body.type == MessageType.TXT) {
    snippet = (latest.body as ChatTextMessageBody).content;
  } else if (latest.body.type == MessageType.IMAGE) {
    snippet = "📷 Mengirim foto";
  }
}
```

### C. Menghapus Percakapan & Riwayat Chat (`deleteConversation`)

Untuk menyelesaikan tiket dan menghapus obrolan dari database lokal Agora:

```dart
// Parameter 1: ID pengguna lawan bicara (conversationId)
// Parameter bernama deleteMessages: true (default true) agar riwayat pesan lokal ikut terhapus bersih
await ChatClient.getInstance.chatManager.deleteConversation(
  targetUserId,
  deleteMessages: true,
);
```

---

## 🛠️ 3. Perubahan & Implementasi Kode

### A. Di Layar Room Chat (`lib/driver_chat_room_screen.dart`)

1. **Aksi Tombol Hapus pada AppBar CS**:
   Di dalam `_buildAppBar()`, jika pengguna yang membuka room chat adalah Customer Service (`widget.isCsRole == true`), ditambahkan tombol icon tempat sampah (`Icons.delete_outline`):

   ```dart
   if (widget.isCsRole)
     IconButton(
       tooltip: "Selesaikan & Hapus Chat",
       icon: const Icon(Icons.delete_outline, color: Colors.red),
       onPressed: _showDeleteChatDialog,
     ),
   ```

2. **Dialog Konfirmasi Hapus**:
   ```dart
   void _showDeleteChatDialog() {
     showDialog(
       context: context,
       builder: (ctx) => AlertDialog(
         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
         title: const Text("Selesaikan & Hapus Chat?"),
         content: const Text(
           "Tiket bantuan ini akan diselesaikan dan riwayat pesan akan dihapus dari antrean CS Anda.",
         ),
         actions: [
           TextButton(
             onPressed: () => Navigator.pop(ctx),
             child: const Text("Batal"),
           ),
           ElevatedButton(
             style: ElevatedButton.styleFrom(
               backgroundColor: Colors.red,
               foregroundColor: Colors.white,
             ),
             onPressed: () async {
               Navigator.pop(ctx);
               try {
                 await ChatClient.getInstance.chatManager.deleteConversation(
                   widget.driverUserId,
                   deleteMessages: true,
                 );
               } catch (e) {
                 debugPrint("Gagal hapus percakapan: $e");
               }
               if (mounted) {
                 Navigator.pop(context); // Kembali ke dashboard
               }
             },
             child: const Text("Hapus"),
           ),
         ],
       ),
     );
   }
   ```

---

### B. Di Dashboard Utama (`lib/main.dart`)

1. **State Percakapan Dinamis**:

   ```dart
   List<ChatConversation> _csConversations = [];
   Map<String, String> _lastMessages = {};
   bool _isLoadingCsConversations = false;
   ```

2. **Method `_loadCsConversations()`**:
   Mengambil percakapan aktif dari Agora Chat SDK dan menyaring obrolan yang memiliki pesan:

   ```dart
   Future<void> _loadCsConversations() async {
     if (!mounted) return;
     setState(() => _isLoadingCsConversations = true);
     try {
       final convs = await ChatClient.getInstance.chatManager.loadAllConversations();
       final Map<String, String> lastMsgs = {};
       final List<ChatConversation> activeConvs = [];

       for (final conv in convs) {
         if (conv.id == _currentUser.id) continue;
         final latest = await conv.latestMessage();
         if (latest != null) {
           activeConvs.add(conv);
           if (latest.body.type == MessageType.TXT) {
             lastMsgs[conv.id] = (latest.body as ChatTextMessageBody).content;
           } else if (latest.body.type == MessageType.IMAGE) {
             lastMsgs[conv.id] = "📷 Mengirim foto";
           } else {
             lastMsgs[conv.id] = "Pesan baru";
           }
         }
       }

       if (mounted) {
         setState(() {
           _csConversations = activeConvs;
           _lastMessages = lastMsgs;
           _isLoadingCsConversations = false;
         });
       }
     } catch (e) {
       debugPrint("[CS INBOX] Gagal: $e");
       if (mounted) setState(() => _isLoadingCsConversations = false);
     }
   }
   ```

3. **Method `_deleteCsConversation()` & Konfirmasi**:

   ```dart
   Future<void> _deleteCsConversation(String conversationId) async {
     try {
       await ChatClient.getInstance.chatManager.deleteConversation(
         conversationId,
         deleteMessages: true,
       );
       if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
           const SnackBar(
             content: Text("Percakapan berhasil diselesaikan dan dihapus."),
             duration: Duration(seconds: 2),
           ),
         );
       }
       await _loadCsConversations();
       await _refreshUnreadCounts();
     } catch (e) {
       debugPrint("[CS INBOX] Gagal hapus: $e");
     }
   }
   ```

4. **Trigger Otomatis Segarkan Inbox**:
   - Saat CS login atau switch user (`_loginAgora()`).
   - Saat ada pesan masuk secara real-time via `onMessagesReceived` di `_setupGlobalMessageAndCallListener()`.
   - Saat CS kembali dari room chat ke dashboard (`_openChatRoom()`).
   - Melalui tombol refresh manual di samping judul inbox.

5. **Tampilan Dinamis Sisi CS (`_buildCsView`)**:
   - **Kondisi Kosong (`_csConversations.isEmpty`)**:
     Menampilkan ikon `Icons.mark_chat_unread_outlined`, ilustrasi _clean_, dan teks penjelasan ramah bahwa antrean chat saat ini kosong.
   - **Kondisi Berisi Obrolan (`_csConversations.isNotEmpty`)**:
     Menampilkan kartu obrolan berisi:
     - Avatar & Nama Pengguna (Penumpang / Driver).
     - Badge role (Driver / Penumpang).
     - Badge jumlah pesan belum dibaca (_unread count_).
     - Cuplikan isi pesan terakhir (_last message snippet_).
     - Tombol **"Balas Chat"**.
     - Tombol **Telepon Langsung**.
     - Tombol **Hapus Chat** (ikon tong sampah merah).
   - **Bagian "Mulai Chat Proaktif"**:
     _ActionChip_ untuk setiap kontak (Driver & Penumpang) jika CS ingin berinisiatif menghubungi mereka terlebih dahulu.

---

## 🧪 4. Langkah Pengujian / Skenario Demo ke Atasan

Berikut panduan langkah demi langkah saat mendemokan aplikasi:

### Skenario 1: Verifikasi Inbox Awal Kosong

1. Buka aplikasi simulator.
2. Klik tombol ganti akun di kanan atas (ikon _switch account_), pilih **Maya (CS Sunjaya Shuttle)**.
3. **Hasil yang terlihat**:
   - Di bagian antrean terdapat tulisan **"0 Obrolan Aktif"**.
   - Muncul kartu _Empty State_ bertuliskan **"Belum Ada Obrolan Masuk"**.
   - Tidak ada list penumpang yang _hardcoded_ lagi seperti aplikasi chat profesional.

### Skenario 2: Penumpang Mengirim Chat ke CS

1. Ganti akun ke **Oding (Penumpang 1)**.
2. Di card bawah _"Butuh Bantuan Perjalanan? Tanya Customer Service"_, klik tombol **"Chat CS"**.
3. Ketik pesan, misalnya: _"Halo min, armada saya berangkat jam berapa ya?"_ atau kirim foto patokan rumah via tombol lampiran (+).
4. Tekan kirim.

### Skenario 3: CS Menerima Chat & Masuk ke Inbox

1. Ganti akun kembali ke **Maya (CS Sunjaya Shuttle)**.
2. **Hasil yang terlihat**:
   - Muncul **"1 Obrolan Aktif"**.
   - Muncul kartu tiket obrolan atas nama **Oding**.
   - Terdapat cuplikan pesan terakhir: _"Halo min, armada saya berangkat jam berapa ya?"_.
   - Terdapat badge pesan baru.
3. CS klik tombol **"Balas Chat"** untuk masuk ke room chat dan membalas pertanyaan Oding.

### Skenario 4: CS Menyelesaikan Tiket & Menghapus Chat

Ada 2 cara yang dapat didemokan ke atasan:

- **Cara 1 (Langsung dari Luar Dashboard)**:
  Klik ikon tong sampah merah di samping kanan kartu obrolan Oding, lalu konfirmasi **"Hapus"**.
- **Cara 2 (Dari Dalam Chat Room)**:
  Saat berada di dalam chat room Oding, klik tombol tong sampah merah di AppBar kanan atas bertuliskan _"Selesaikan & Hapus Chat"_, lalu konfirmasi.
- **Hasil**:
  Layar kembali ke Dashboard CS. Obrolan Oding telah terhapus bersih dan tampilan kembali ke **"Belum Ada Obrolan Masuk"** (_Empty State_).

### Skenario 5: CS Memulai Chat Proaktif

1. Di bagian bawah dashboard CS, klik salah satu chip di _"Mulai Chat Proaktif (Hubungi Pengguna)"_, misalnya klik **Pak Ibnu (Driver HiAce)**.
2. Kirim pesan ke Driver.
3. Saat kembali ke dashboard CS, obrolan dengan Driver sekarang otomatis masuk ke daftar obrolan aktif CS.

---

## 🚀 5. Kesimpulan & Manfaat bagi `sunjaya_mobile`

Dengan implementasi ini:

1. **Sesuai Standar Aplikasi Chat Modern**: Mengadopsi prinsip antrean berbasis event/percakapan nyata (_inbox-driven_), bukan data statis.
2. **Menghemat Penyimpanan HP**: Fitur hapus riwayat membersihkan database lokal SQLite Agora dari chat-chat lama yang sudah tuntas.
3. **Fleksibel**: CS tetap bisa menjangkau armada driver maupun penumpang kapan saja melalui fitur inisiasi chat proaktif.
