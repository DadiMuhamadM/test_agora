import 'dart:async';
import 'dart:io';
import 'package:agora_chat_sdk/agora_chat_sdk.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'call_screen.dart';
import 'core/res/colors.dart';
import 'main.dart'; // Mengambil AgoraConfig

/// Tipe isi pesan chat shuttle
enum ShuttleMessageType { text, image }

/// Model data pesan obrolan antara Customer dan Driver Shuttle
class ShuttleChatMessage {
  final String? msgId; // ID unik pesan Agora
  final ShuttleMessageType type; // text atau image
  final String text; // Isi teks pesan atau caption/nama foto
  final bool
  isMe; // true jika dikirim oleh Customer (kita), false jika dari Driver
  final DateTime time; // Waktu pesan
  final String? localPath; // File path lokal di HP
  final String? remoteUrl; // URL gambar di Agora Cloud CDN
  final String? thumbnailUrl; // URL thumbnail di Agora Cloud CDN
  final int? fileSize;
  bool isRead; // true jika sudah dibaca oleh lawan bicara (ceklis 2 biru WhatsApp)
  bool isDelivered; // true jika sudah sampai di HP penerima (ceklis 2 abu-abu)

  ShuttleChatMessage({
    this.msgId,
    this.type = ShuttleMessageType.text,
    required this.text,
    required this.isMe,
    required this.time,
    this.localPath,
    this.remoteUrl,
    this.thumbnailUrl,
    this.fileSize,
    this.isRead = false,
    this.isDelivered = false,
  });

  bool get isImage => type == ShuttleMessageType.image;
}

// Alias untuk kompatibilitas jika nama sebelumnya digunakan
typedef DriverChatMessage = ShuttleChatMessage;
typedef DriverChatRoomScreen = ChatDriverScreen;

/// ============================================================================
/// LAYAR ROOM CHAT SISI CUSTOMER (PENUMPANG)
/// ============================================================================
/// Layar ini dipasang pada aplikasi Customer (sunjaya_mobile) untuk berkomunikasi
/// langsung dengan Driver Shuttle yang ditugaskan menjemputnya.
///
/// Panggil dari Layar Pelacakan Jemputan (LokasiDriverScreen / BookingDetailScreen):
/// Navigator.push(
///   context,
///   MaterialPageRoute(
///     builder: (_) => ChatDriverScreen(
///       driverName: 'Pak Dika (Driver Shuttle)',
///       driverUserId: 'dhika-driver',    // ID Agora Driver dari backend
///       customerUserId: 'dhadi-cust',   // ID Agora Customer yang sedang login
///     ),
///   ),
/// );
class ChatDriverScreen extends StatefulWidget {
  final String driverName; // Nama lawan bicara yang ditampilkan di AppBar
  final String driverUserId; // ID Agora milik lawan bicara
  final String customerUserId; // ID Agora milik akun kita sendiri
  final String customerToken; // Token Agora untuk otentikasi akun kita
  final String appKey; // App Key Agora Chat
  final bool isDriverRole; // true jika pengirim adalah driver
  final bool isCsRole; // true jika pengirim adalah Customer Service (CS)
  final bool isChatWithCs; // true jika lawan bicara adalah CS
  final String?
  targetSubtitle; // info subtitle (misal: "Kursi 1A" atau "Pusat Bantuan 24 Jam")

  ChatDriverScreen({
    super.key,
    required this.driverName,
    String? driverUserId,
    String? customerUserId,
    String? targetUserId,
    String? currentUserId,
    String? customerToken,
    String? appKey,
    this.isDriverRole = false,
    this.isCsRole = false,
    this.isChatWithCs = false,
    this.targetSubtitle,
  }) : driverUserId = driverUserId ?? targetUserId ?? AgoraConfig.driverId,
       customerUserId =
           customerUserId ?? currentUserId ?? AgoraConfig.penumpangId,
       customerToken = customerToken ?? AgoraConfig.penumpangToken,
       appKey = appKey ?? AgoraConfig.appKey;

  @override
  State<ChatDriverScreen> createState() => _ChatDriverScreenState();
}

class _ChatDriverScreenState extends State<ChatDriverScreen> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();

  // Template balasan cepat dinamis berdasarkan konteks obrolan (CS / Driver / Penumpang)
  List<String> get _quickReplies {
    if (widget.isCsRole) {
      return [
        'Halo kak, ada yang bisa kami bantu seputar tiket shuttle?',
        'Mohon sebutkan kode booking atau nomor tiket Anda kak.',
        'Baik kak, kami sedang koordinasikan dengan driver armada.',
        'Titik jemput Anda sudah berhasil kami konfirmasi ya kak.',
        'Terima kasih telah menggunakan layanan Sunjaya Shuttle!',
      ];
    } else if (widget.isChatWithCs) {
      return [
        'Halo kak, mau tanya jadwal keberangkatan armada saya',
        'Bisa bantu cek posisi armada driver jemputan saya?',
        'Bisa tolong ubah titik penjemputan tiket saya kak?',
        'Ada barang saya yang tertinggal di shuttle kak',
        'Terima kasih banyak atas bantuannya kak!',
      ];
    } else if (widget.isDriverRole) {
      return [
        'Saya sudah di titik jemput',
        'Armada sudah sampai di depan',
        'Apakah Anda sudah siap?',
        'Mohon tunggu sebentar ya',
        'Terima kasih',
      ];
    } else {
      return [
        'Saya sudah di lokasi jemput',
        'Saya di depan lobi utama',
        'Posisi bapak sudah sampai mana?',
        'Mohon tunggu sebentar',
        'Terima kasih pak',
      ];
    }
  }

  // List data pesan chat yang terhubung ke server Agora
  final List<ShuttleChatMessage> _messages = [];
  bool _isInitializing = true;
  final ImagePicker _picker = ImagePicker();
  bool _isUploadingImage = false;

  @override
  void initState() {
    super.initState();
    // Inisialisasi SDK, login, muat riwayat obrolan, dan pasang listener
    _initAgoraAndHistory();
  }

  // ==========================================================================
  // 0. INISIALISASI OTOMATIS & LOGIN KE AGORA CHAT
  // ==========================================================================
  Future<void> _initAgoraAndHistory() async {
    // 1. Pastikan SDK terinisialisasi dan koneksi login aktif ke server Agora
    await _ensureAgoraInitializedAndLoggedIn();
    // 2. Pasang listener pesan real-time
    _setupAgoraListener();
    // 3. Muat riwayat chat (lokal + server)
    await _loadAgoraHistory();
    // 4. Kirim konfirmasi sudah dibaca (Read Ack) ke lawan bicara
    _sendReadAck();
    if (mounted) {
      setState(() {
        _isInitializing = false;
      });
    }
  }

  // ==========================================================================
  // KIRIM TANDA SUDAH DIBACA (READ RECEIPT / CEKLIS BIRU) KE LAWAN BICARA
  // ==========================================================================
  Future<void> _sendReadAck() async {
    try {
      final conv = await ChatClient.getInstance.chatManager
          .getConversation(widget.driverUserId);
      await conv?.markAllMessagesAsRead();
      await ChatClient.getInstance.chatManager
          .sendConversationReadAck(widget.driverUserId);
      debugPrint(
        "[CUSTOMER CHAT] 👀 Konfirmasi baca (Read Ack) berhasil dikirim ke ${widget.driverUserId}",
      );
    } catch (e) {
      debugPrint("[CUSTOMER CHAT] Gagal kirim read ack: $e");
    }
  }

  Future<void> _ensureAgoraInitializedAndLoggedIn() async {
    try {
      debugPrint("[CUSTOMER CHAT] 🚀 Memeriksa inisialisasi Agora Chat SDK...");
      ChatOptions options = ChatOptions.withAppKey(
        widget.appKey,
        autoLogin: true,
        requireAck: true,
        requireDeliveryAck: true,
      );
      await ChatClient.getInstance.init(options);
      await ChatClient.getInstance.startCallback();

      final current = ChatClient.getInstance.currentUserId;
      bool isConnected = false;
      try {
        isConnected = await ChatClient.getInstance.isConnected();
      } catch (_) {}

      debugPrint(
        "[CUSTOMER CHAT] Status koneksi: currentUserId=$current, isConnected=$isConnected",
      );

      // Jika belum terhubung ke server Agora ATAU user di memori bukan customerUserId kita:
      if (!isConnected || current != widget.customerUserId) {
        debugPrint(
          "[CUSTOMER CHAT] 🔐 Menjalankan login Agora Chat sebagai: ${widget.customerUserId}...",
        );
        // Jika akun di HP berbeda dengan akun kita sekarang, logout terlebih dahulu
        if (current != null && current != widget.customerUserId) {
          try {
            await ChatClient.getInstance.logout(true);
          } catch (_) {}
        }

        try {
          await ChatClient.getInstance.loginWithToken(
            widget.customerUserId,
            widget.customerToken,
          );
          debugPrint("[CUSTOMER CHAT] ✅ Berhasil login ke Agora Chat!");
        } on ChatError catch (ce) {
          if (ce.code == 200) {
            debugPrint("[CUSTOMER CHAT] ✅ Sesi sudah login (Code 200)");
          } else {
            debugPrint(
              "[CUSTOMER CHAT] ❌ ChatError saat login: ${ce.code} - ${ce.description}",
            );
            rethrow;
          }
        }
      } else {
        debugPrint(
          "[CUSTOMER CHAT] ✅ Sesi aktif dan terhubung (${widget.customerUserId})",
        );
      }
    } catch (e) {
      debugPrint("[CUSTOMER CHAT] ⚠️ Inisialisasi/Login Agora Chat: $e");
    }
  }

  @override
  void dispose() {
    // Wajib melepas listener saat customer keluar dari room chat
    ChatClient.getInstance.chatManager.removeEventHandler(
      "CUSTOMER_ROOM_CHAT_HANDLER",
    );
    _controller.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ==========================================================================
  // 1. MEMUAT RIWAYAT OBROLAN DENGAN DRIVER (LOKAL & SERVER AGORA)
  // ==========================================================================
  Future<void> _loadAgoraHistory() async {
    debugPrint(
      "[CUSTOMER CHAT] 📥 Memuat riwayat chat dengan Driver (${widget.driverUserId})...",
    );
    try {
      final conversation = await ChatClient.getInstance.chatManager
          .getConversation(widget.driverUserId, createIfNeed: true);

      // Tandai semua pesan sebagai terbaca saat membuka room chat
      if (conversation != null) {
        await conversation.markAllMessagesAsRead();
      }

      List<ChatMessage> list = [];

      // A. Coba muat pesan dari penyimpanan lokal perangkat
      if (conversation != null) {
        list = await conversation.loadMessages(
          loadCount: 50,
          direction: ChatSearchDirection.Up,
        );
      }

      // B. Jika di memori lokal masih kosong, ambil dari Server Agora (Roaming Messages)
      if (list.isEmpty) {
        debugPrint(
          "[CUSTOMER CHAT] ☁️ Database lokal kosong, mengambil riwayat dari server Agora...",
        );
        try {
          final result = await ChatClient.getInstance.chatManager
              .fetchHistoryMessagesByOption(
                widget.driverUserId,
                ChatConversationType.Chat,
                options: FetchMessageOptions(
                  direction: ChatSearchDirection.Up,
                  needSave:
                      true, // Simpan ke database lokal agar pembukaan berikutnya instan
                ),
                pageSize: 50,
              );
          list = result.data;
          debugPrint(
            "[CUSTOMER CHAT] ☁️ Berhasil mengambil ${list.length} pesan dari server Agora",
          );
        } catch (serverErr) {
          debugPrint(
            "[CUSTOMER CHAT] Fetch dari server gagal/offline: $serverErr",
          );
        }
      }

      // C. Urutkan secara kronologis dari yang terlama ke terbaru
      // Karena loadMessages dengan SearchDirection.Up mengembalikan urutan terbalik
      list.sort((a, b) {
        final tA = a.serverTime > 0 ? a.serverTime : a.localTime;
        final tB = b.serverTime > 0 ? b.serverTime : b.localTime;
        return tA.compareTo(tB);
      });

      List<ShuttleChatMessage> history = [];
      for (var msg in list) {
        if (msg.body.type == MessageType.TXT) {
          // Saring sinyal telepon masuk agar tidak muncul sebagai gelembung chat
          if (msg.attributes != null &&
              msg.attributes!["action"] == "CALL_INVITE") {
            continue;
          }
          final body = msg.body as ChatTextMessageBody;
          // Jika pengirim adalah customerUserId, berarti pesan dikirim oleh customer (isMe = true)
          final isMe = msg.from == widget.customerUserId;
          final timestamp = msg.serverTime > 0 ? msg.serverTime : msg.localTime;

          history.add(
            ShuttleChatMessage(
              msgId: msg.msgId,
              type: ShuttleMessageType.text,
              text: body.content,
              isMe: isMe,
              time: DateTime.fromMillisecondsSinceEpoch(timestamp),
              isRead: msg.hasReadAck,
              isDelivered: msg.hasDeliverAck,
            ),
          );
        } else if (msg.body.type == MessageType.IMAGE) {
          final body = msg.body as ChatImageMessageBody;
          final isMe = msg.from == widget.customerUserId;
          final timestamp = msg.serverTime > 0 ? msg.serverTime : msg.localTime;

          // Prioritaskan path lokal (full image atau thumbnail yang sudah di-cache SDK Agora)
          String? validLocalPath;
          if (body.localPath != null &&
              body.localPath!.isNotEmpty &&
              File(body.localPath!).existsSync()) {
            validLocalPath = body.localPath;
          } else if (body.thumbnailLocalPath != null &&
              body.thumbnailLocalPath!.isNotEmpty &&
              File(body.thumbnailLocalPath!).existsSync()) {
            validLocalPath = body.thumbnailLocalPath;
          }

          history.add(
            ShuttleChatMessage(
              msgId: msg.msgId,
              type: ShuttleMessageType.image,
              text: body.displayName ?? '',
              isMe: isMe,
              time: DateTime.fromMillisecondsSinceEpoch(timestamp),
              localPath: validLocalPath,
              remoteUrl: body.remotePath,
              thumbnailUrl: body.thumbnailRemotePath ?? body.remotePath,
              fileSize: body.fileSize,
              isRead: msg.hasReadAck,
              isDelivered: msg.hasDeliverAck,
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

  // ==========================================================================
  // 2. LISTENER UNTUK MENERIMA PESAN & PANGGILAN REAL-TIME DARI DRIVER
  // ==========================================================================
  void _setupAgoraListener() {
    debugPrint("[CUSTOMER CHAT] 🎧 Memasang listener pesan masuk...");
    ChatClient.getInstance.chatManager.removeEventHandler(
      "CUSTOMER_ROOM_CHAT_HANDLER",
    );
    ChatClient.getInstance.chatManager.addEventHandler(
      "CUSTOMER_ROOM_CHAT_HANDLER",
      ChatEventHandler(
        onMessagesReceived: (List<ChatMessage> messages) {
          debugPrint(
            "[CUSTOMER CHAT] 📩 Event onMessagesReceived diterima: ${messages.length} pesan baru",
          );
          for (var msg in messages) {
            final sender = msg.from?.trim().toLowerCase() ?? '';
            final convId = msg.conversationId?.trim().toLowerCase() ?? '';
            final expectedSender = widget.driverUserId.trim().toLowerCase();

            // Pastikan pesan berasal dari driver yang bersangkutan
            if (sender == expectedSender || convId == expectedSender) {
              // Tandai sebagai terbaca & kirim read ack karena user sedang berada di dalam room chat ini
              _sendReadAck();
              // A. Sinyal Panggilan Telepon Masuk dari Driver
              if (msg.attributes != null &&
                  msg.attributes!["action"] == "CALL_INVITE") {
                // Cek kadaluarsa panggilan (maksimal 35 detik)
                final callTime = (msg.attributes!["callTime"] as int?) ??
                    (msg.serverTime > 0 ? msg.serverTime : msg.localTime);
                if (callTime > 0) {
                  final ageInSeconds =
                      (DateTime.now().millisecondsSinceEpoch - callTime) / 1000;
                  if (ageInSeconds > 35) {
                    debugPrint(
                      "[CHAT ROOM] ⚠️ Panggilan lama terdeteksi (${ageInSeconds.toStringAsFixed(1)}s lalu), pop-up diabaikan.",
                    );
                    continue;
                  }
                }

                final channelId =
                    msg.attributes!["channelId"] as String? ??
                    AgoraConfig.channelId;
                final isVideo = msg.attributes!["isVideo"] as bool? ?? false;
                _showIncomingCallDialog(
                  caller: widget.driverName,
                  channelId: channelId,
                  isVideo: isVideo,
                );
                continue;
              }

              // B. Pesan Teks Balasan Masuk dari Lawan Bicara
              if (msg.body.type == MessageType.TXT) {
                final body = msg.body as ChatTextMessageBody;
                final timestamp = msg.serverTime > 0
                    ? msg.serverTime
                    : (msg.localTime > 0
                          ? msg.localTime
                          : DateTime.now().millisecondsSinceEpoch);

                debugPrint(
                  "[CUSTOMER CHAT] 💬 Pesan baru masuk realtime: \"${body.content}\"",
                );

                if (mounted) {
                  setState(() {
                    _messages.add(
                      ShuttleChatMessage(
                        msgId: msg.msgId,
                        type: ShuttleMessageType.text,
                        text: body.content,
                        isMe: false, // Pesan masuk dari lawan bicara
                        time: DateTime.fromMillisecondsSinceEpoch(timestamp),
                      ),
                    );
                  });
                  _scrollToBottom();
                }
              }
              // C. Pesan Foto Masuk dari Lawan Bicara
              else if (msg.body.type == MessageType.IMAGE) {
                final body = msg.body as ChatImageMessageBody;
                final timestamp = msg.serverTime > 0
                    ? msg.serverTime
                    : (msg.localTime > 0
                          ? msg.localTime
                          : DateTime.now().millisecondsSinceEpoch);

                debugPrint(
                  "[CUSTOMER CHAT] 🖼️ Foto baru masuk realtime: remote=${body.remotePath}, thumb=${body.thumbnailRemotePath}",
                );

                // Prioritaskan path lokal jika SDK Agora sudah mengunduhnya secara otomatis
                String? validLocalPath;
                if (body.localPath != null &&
                    body.localPath!.isNotEmpty &&
                    File(body.localPath!).existsSync()) {
                  validLocalPath = body.localPath;
                } else if (body.thumbnailLocalPath != null &&
                    body.thumbnailLocalPath!.isNotEmpty &&
                    File(body.thumbnailLocalPath!).existsSync()) {
                  validLocalPath = body.thumbnailLocalPath;
                }

                if (mounted) {
                  setState(() {
                    _messages.add(
                      ShuttleChatMessage(
                        msgId: msg.msgId,
                        type: ShuttleMessageType.image,
                        text: body.displayName ?? '',
                        isMe: false, // Pesan foto masuk dari lawan bicara
                        time: DateTime.fromMillisecondsSinceEpoch(timestamp),
                        localPath: validLocalPath,
                        remoteUrl: body.remotePath,
                        thumbnailUrl:
                            body.thumbnailRemotePath ?? body.remotePath,
                        fileSize: body.fileSize,
                      ),
                    );
                  });
                  _scrollToBottom();
                }
              }
            } else {
              // Notifikasi jika ada pesan/telepon dari pengguna lain saat sedang di room chat ini
              if (msg.attributes != null &&
                  msg.attributes!["action"] == "CALL_INVITE") {
                // Cek kadaluarsa panggilan (maksimal 35 detik)
                final callTime = (msg.attributes!["callTime"] as int?) ??
                    (msg.serverTime > 0 ? msg.serverTime : msg.localTime);
                if (callTime > 0) {
                  final ageInSeconds =
                      (DateTime.now().millisecondsSinceEpoch - callTime) / 1000;
                  if (ageInSeconds > 35) {
                    continue;
                  }
                }

                final channelId =
                    msg.attributes!["channelId"] as String? ??
                    AgoraConfig.channelId;
                final isVideo = msg.attributes!["isVideo"] as bool? ?? false;
                final callerId = msg.from ?? "Pengguna Lain";
                _showIncomingCallDialog(
                  caller: callerId,
                  channelId: channelId,
                  isVideo: isVideo,
                );
              } else {
                final otherSender = msg.from ?? "Pengguna";
                String snippet = "Pesan baru masuk";
                if (msg.body.type == MessageType.TXT) {
                  snippet = (msg.body as ChatTextMessageBody).content;
                } else if (msg.body.type == MessageType.IMAGE) {
                  snippet = "📷 Mengirim foto";
                }

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      behavior: SnackBarBehavior.floating,
                      margin: const EdgeInsets.all(12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      content: Row(
                        children: [
                          const Icon(
                            Icons.notifications_active,
                            color: Colors.white,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              "$otherSender: $snippet",
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                      duration: const Duration(seconds: 3),
                    ),
                  );
                }
              }
            }
          }
        },
        // Callback ketika lawan bicara membaca percakapan kita (Read Receipt / Ceklis Biru)
        onConversationRead: (String from, String to) {
          debugPrint(
            "[CUSTOMER CHAT] 👀 Lawan bicara ($from) telah membaca percakapan!",
          );
          if (from.trim().toLowerCase() ==
              widget.driverUserId.trim().toLowerCase()) {
            if (mounted) {
              setState(() {
                for (var m in _messages) {
                  if (m.isMe) {
                    m.isRead = true;
                  }
                }
              });
            }
          }
        },
        // Callback ketika pesan tertentu telah dibaca oleh lawan bicara
        onMessagesRead: (List<ChatMessage> readList) {
          debugPrint(
            "[CUSTOMER CHAT] 👀 ${readList.length} pesan telah dibaca oleh lawan bicara",
          );
          if (mounted) {
            setState(() {
              for (var readMsg in readList) {
                final idx =
                    _messages.indexWhere((m) => m.msgId == readMsg.msgId);
                if (idx != -1) {
                  _messages[idx].isRead = true;
                }
              }
            });
          }
        },
        // Callback ketika pesan telah sampai di perangkat penerima (Ceklis Dua Abu-abu)
        onMessagesDelivered: (List<ChatMessage> delList) {
          debugPrint(
            "[CUSTOMER CHAT] 🚚 ${delList.length} pesan telah terkirim ke perangkat penerima",
          );
          if (mounted) {
            setState(() {
              for (var delMsg in delList) {
                final idx =
                    _messages.indexWhere((m) => m.msgId == delMsg.msgId);
                if (idx != -1) {
                  _messages[idx].isDelivered = true;
                }
              }
            });
          }
        },
      ),
    );
  }

  // ==========================================================================
  // 3. CUSTOMER MENGIRIM PESAN TEKS KE DRIVER
  // ==========================================================================
  Future<void> _send([String? quickText]) async {
    final text = (quickText ?? _controller.text).trim();
    if (text.isEmpty) return;

    debugPrint(
      "[CUSTOMER CHAT] Mengirim pesan: \"$text\" -> Ke Driver: ${widget.driverUserId}",
    );

    // Buat pesan dengan target driverUserId
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
              msgId: msg.msgId,
              type: ShuttleMessageType.text,
              text: text,
              isMe: true, // Pesan kita sendiri sebagai Customer
              time: DateTime.now(),
              isRead: false,
              isDelivered: false,
            ),
          );
        });
        _controller.clear();
        _scrollToBottom();
      }
    } catch (e) {
      debugPrint("[CUSTOMER CHAT] Gagal kirim pesan: $e");
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Gagal mengirim pesan: $e")));
      }
    }
  }

  // ==========================================================================
  // 3B. PENGIRIMAN FOTO & GAMBAR (AGORA CHAT MEDIA)
  // ==========================================================================
  void _showAttachmentSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                const Text(
                  "Kirim Gambar / Foto",
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "Pilih foto langsung dari kamera atau galeri perangkat.",
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildAttachOptionItem(
                      icon: Icons.camera_alt_rounded,
                      color: Colors.blue.shade600,
                      label: "Kamera",
                      subtitle: "Ambil foto langsung",
                      onTap: () {
                        Navigator.pop(ctx);
                        _pickAndSendImage(ImageSource.camera);
                      },
                    ),
                    _buildAttachOptionItem(
                      icon: Icons.photo_library_rounded,
                      color: Colors.purple.shade600,
                      label: "Galeri",
                      subtitle: "Pilih foto tersimpan",
                      onTap: () {
                        Navigator.pop(ctx);
                        _pickAndSendImage(ImageSource.gallery);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAttachOptionItem({
    required IconData icon,
    required Color color,
    required String label,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 140,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.2)),
        ),
        child: Column(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: color,
              child: Icon(icon, color: Colors.white, size: 24),
            ),
            const SizedBox(height: 10),
            Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickAndSendImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        imageQuality: 70, // Kompresi 70% agar cepat terkirim & hemat kuota
        maxWidth: 1280,
        maxHeight: 1280,
      );

      if (pickedFile == null) return;

      final filePath = pickedFile.path;
      final fileName = pickedFile.name;

      if (mounted) {
        setState(() {
          _isUploadingImage = true;
        });
      }

      debugPrint(
        "[CHAT UPLOAD] 📤 Mengirim gambar: $filePath ($fileName) ke ${widget.driverUserId}...",
      );

      // 1. Buat pesan gambar Agora Chat
      final msg = ChatMessage.createImageSendMessage(
        targetId: widget.driverUserId,
        filePath: filePath,
        displayName: fileName,
        sendOriginalImage: false,
      );

      // 2. Kirim via Agora Chat SDK (Agora otomatis mengupload ke Agora Cloud Storage/CDN)
      await ChatClient.getInstance.chatManager.sendMessage(msg);

      debugPrint("[CHAT UPLOAD] ✅ Foto berhasil dikirim ke Agora Chat!");

      // 3. Tambahkan ke tampilan UI (Optimistic UI)
      if (mounted) {
        setState(() {
          _messages.add(
            ShuttleChatMessage(
              msgId: msg.msgId,
              type: ShuttleMessageType.image,
              text: fileName,
              isMe: true,
              time: DateTime.now(),
              localPath: filePath,
              isRead: false,
              isDelivered: false,
            ),
          );
          _isUploadingImage = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      debugPrint("[CHAT UPLOAD] ❌ Gagal mengirim gambar: $e");
      if (mounted) {
        setState(() {
          _isUploadingImage = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Gagal mengirim foto: $e"),
            backgroundColor: Colors.red.shade700,
          ),
        );
      }
    }
  }

  // ==========================================================================
  // 4. MEMULAI PANGGILAN SUARA / VIDEO (AGORA RTC)
  // ==========================================================================
  Future<void> _startCall({required bool isVideo}) async {
    final ids = [widget.customerUserId, widget.driverUserId]..sort();
    final channelId = AgoraConfig.channelId.isNotEmpty
        ? AgoraConfig.channelId
        : "shuttle_${ids[0]}_${ids[1]}";

    debugPrint(
      "[CALL] Memulai ${isVideo ? 'Video' : 'Voice'} Call ke ${widget.driverName} (Channel: $channelId)...",
    );

    // 1. Kirim sinyal dering ke HP lawan bicara via Agora Chat
    final callMsg = ChatMessage.createTxtSendMessage(
      targetId: widget.driverUserId,
      content: isVideo
          ? "📹 Panggilan Video Masuk..."
          : "📞 Panggilan Suara Masuk...",
    );
    callMsg.attributes = {
      "action": "CALL_INVITE",
      "channelId": channelId,
      "isVideo": isVideo,
      "caller": widget.customerUserId,
      "callerName": widget.isDriverRole ? "Driver Shuttle" : "Penumpang",
      "callTime": DateTime.now().millisecondsSinceEpoch,
    };

    try {
      await ChatClient.getInstance.chatManager.sendMessage(callMsg);
    } catch (e) {
      debugPrint("[CALL] Gagal kirim sinyal telepon: $e");
    }

    // 2. Buka Layar CallScreen
    if (mounted) {
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

  bool _isIncomingCallDialogShowing = false;

  // Pop-up dialog jika Driver menelepon Customer saat sedang di room chat
  void _showIncomingCallDialog({
    required String caller,
    required String channelId,
    required bool isVideo,
  }) {
    if (!mounted || _isIncomingCallDialogShowing) return;
    _isIncomingCallDialogShowing = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          backgroundColor: const Color(0xFF1E1E2C),
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                CircleAvatar(
                  radius: 36,
                  backgroundColor: isVideo
                      ? Colors.blue.shade700
                      : Colors.green.shade700,
                  child: Icon(
                    isVideo ? Icons.videocam : Icons.phone_in_talk,
                    size: 38,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  isVideo
                      ? "Panggilan Video dari Driver"
                      : "Panggilan Suara dari Driver",
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 6),
                Text(
                  caller,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
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
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () {
                        _isIncomingCallDialogShowing = false;
                        Navigator.of(dialogContext).pop();
                      },
                      icon: const Icon(Icons.call_end),
                      label: const Text("Tolak"),
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade600,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () {
                        // Gunakan pushReplacement agar rute Dialog digantikan secara total oleh CallScreen.
                        // Saat telepon selesai (CallScreen di-pop), layar kembali langsung ke Room Chat tanpa dialog sisa!
                        Navigator.pushReplacement(
                          dialogContext,
                          MaterialPageRoute(
                            builder: (context) => CallScreen(
                              channelId: channelId,
                              isVideoCall: isVideo,
                              targetName: caller,
                            ),
                          ),
                        ).then((_) {
                          _isIncomingCallDialogShowing = false;
                        });
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
    ).then((_) {
      _isIncomingCallDialogShowing = false;
    });
  }

  // Dialog konfirmasi hapus riwayat chat (untuk CS / pengguna)
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

  void _fillQuickReply(String text) {
    _controller.text = text;
    _controller.selection = TextSelection.fromPosition(
      TextPosition(offset: text.length),
    );
    _focusNode.requestFocus();
  }

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

  String _formatTime(DateTime t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F8FA),
      appBar: _buildAppBar(context),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(child: _buildMessageList()),
            _buildQuickReplies(),
            if (_isUploadingImage) _buildUploadProgressBar(),
            _buildInputBar(),
          ],
        ),
      ),
    );
  }

  // ==========================================================================
  // APPBAR SISI CUSTOMER: MENAMPILKAN PROFIL DRIVER YANG MENJEMPUT
  // ==========================================================================
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
            backgroundColor: (widget.isChatWithCs || widget.isCsRole)
                ? Colors.purple.withOpacity(0.12)
                : COLORS.primary.withOpacity(0.1),
            child: Icon(
              (widget.isChatWithCs || widget.isCsRole)
                  ? Icons.support_agent
                  : Icons.person,
              color: (widget.isChatWithCs || widget.isCsRole)
                  ? Colors.purple.shade700
                  : COLORS.primary,
              size: 22,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.driverName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: Colors.black87,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      widget.targetSubtitle ??
                          (widget.isChatWithCs
                              ? 'Customer Service • Online 24 Jam'
                              : (widget.isCsRole
                                    ? 'Pelanggan Shuttle • Online'
                                    : (widget.isDriverRole
                                          ? 'Penumpang • Online'
                                          : 'Driver Shuttle • Online'))),
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        if (widget.isCsRole)
          IconButton(
            tooltip: "Selesaikan & Hapus Chat",
            icon: const Icon(Icons.delete_outline, color: Colors.red),
            onPressed: _showDeleteChatDialog,
          ),
        IconButton(
          tooltip: widget.isChatWithCs
              ? "Telepon CS"
              : (widget.isCsRole ? "Telepon Pelanggan" : "Telepon Driver"),
          onPressed: () => _startCall(isVideo: false),
          icon: const Icon(Icons.phone, color: COLORS.primary),
        ),
        IconButton(
          tooltip: widget.isChatWithCs
              ? "Video Call CS"
              : (widget.isCsRole
                    ? "Video Call Pelanggan"
                    : "Video Call Driver"),
          onPressed: () => _startCall(isVideo: true),
          icon: const Icon(Icons.videocam, color: COLORS.primary),
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  // ==========================================================================
  // LIST PESAN OBROLAN
  // ==========================================================================
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

  // ==========================================================================
  // PROGRESS BAR SAAT MENGUNGGAH FOTO KE AGORA CDN
  // ==========================================================================
  Widget _buildUploadProgressBar() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: Colors.blue.shade50,
      child: Row(
        children: [
          const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              "Mengunggah gambar ke server Agora...",
              style: TextStyle(
                fontSize: 12,
                color: Colors.blue.shade900,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // PREVIEW FOTO LAYAR PENUH (INTERACTIVE VIEWER PINCH TO ZOOM)
  // ==========================================================================
  void _showImagePreviewDialog(ShuttleChatMessage msg) {
    showDialog(
      context: context,
      builder: (dialogCtx) => Dialog(
        backgroundColor: Colors.black.withOpacity(0.92),
        insetPadding: EdgeInsets.zero,
        child: Stack(
          alignment: Alignment.center,
          children: [
            InteractiveViewer(
              panEnabled: true,
              minScale: 0.8,
              maxScale: 4.0,
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
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
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

  Widget _buildImageContent(
    ShuttleChatMessage msg, {
    BoxFit fit = BoxFit.cover,
  }) {
    // 1. Cek file lokal di perangkat (misal baru diambil atau sudah ter-cache)
    if (msg.localPath != null &&
        msg.localPath!.isNotEmpty &&
        File(msg.localPath!).existsSync()) {
      return Image.file(
        File(msg.localPath!),
        fit: fit,
        errorBuilder: (_, __, ___) => _buildImageErrorPlaceholder(),
      );
    }

    // 2. Gunakan URL remote / thumbnail dari Agora Cloud CDN
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
        errorBuilder: (_, __, ___) => _buildImageErrorPlaceholder(),
      );
    }

    return _buildImageErrorPlaceholder();
  }

  Widget _buildImageErrorPlaceholder() {
    return Container(
      height: 150,
      color: Colors.grey.shade200,
      alignment: Alignment.center,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.broken_image, color: Colors.grey.shade500, size: 36),
          const SizedBox(height: 6),
          Text(
            "Foto tidak dapat dimuat",
            style: TextStyle(color: Colors.grey.shade600, fontSize: 11),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // BUBBLE BALON CHAT: CUSTOMER (KANAN/BIRU) VS DRIVER (KIRI/PUTIH)
  // ==========================================================================
  Widget _buildBubble(ShuttleChatMessage msg) {
    final isMe = msg.isMe; // true = Customer kita sendiri, false = Lawan bicara

    // Tampilan khusus pesan Gambar
    if (msg.isImage) {
      return Align(
        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 4),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.72,
          ),
          decoration: BoxDecoration(
            color: isMe ? COLORS.primary : Colors.white,
            border: isMe ? null : Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
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
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.55),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: _buildMessageStatus(msg, isImage: true),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.72,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isMe ? COLORS.primary : Colors.white,
          border: isMe ? null : Border.all(color: Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
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
            _buildMessageStatus(msg, isImage: false),
          ],
        ),
      ),
    );
  }

  // ==========================================================================
  // STATUS WAKTU & TANDA CEKLIS (CEKLIS 1 TERKIRIM, CEKLIS 2 ABU, CEKLIS 2 BIRU)
  // ==========================================================================
  Widget _buildMessageStatus(ShuttleChatMessage msg, {bool isImage = false}) {
    final isMe = msg.isMe;
    final timeColor = isImage
        ? Colors.white
        : (isMe ? Colors.white70 : Colors.grey[500]);

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Waktu pengiriman pesan (di bawah chat)
        Text(
          _formatTime(msg.time),
          style: TextStyle(
            fontSize: 10.5,
            color: timeColor,
            fontWeight: isImage ? FontWeight.w500 : FontWeight.normal,
          ),
        ),
        if (isMe) ...[
          const SizedBox(width: 4),
          if (msg.isRead)
            // 🔵 Ceklis Dua Biru WhatsApp (Pesan Sudah Dibaca)
            const Icon(
              Icons.done_all,
              size: 15,
              color: Color(0xFF00E5FF), // Biru Cyan Terang khas WA (Sangat Kontras)
            )
          else if (msg.isDelivered)
            // ⚪ Ceklis Dua Abu-abu / Putih (Pesan Sudah Terkirim ke Penerima)
            const Icon(
              Icons.done_all,
              size: 15,
              color: Colors.white70,
            )
          else
            // ⚪ Ceklis Satu (Pesan Berhasil Terkirim ke Server)
            const Icon(
              Icons.done,
              size: 15,
              color: Colors.white70,
            ),
        ],
      ],
    );
  }

  // ==========================================================================
  // BALASAN CEPAT CUSTOMER KE DRIVER
  // ==========================================================================
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
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            onPressed: () => _fillQuickReply(_quickReplies[i]),
          );
        },
      ),
    );
  }

  // ==========================================================================
  // INPUT BAR BAWAH DENGAN TOMBOL KIRIM GAMBAR / FOTO
  // ==========================================================================
  Widget _buildInputBar() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(10, 8, 16, 12),
      child: Row(
        children: [
          IconButton(
            tooltip: "Kirim Gambar",
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: COLORS.primary.withOpacity(0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.add_a_photo_outlined,
                color: COLORS.primary,
                size: 20,
              ),
            ),
            onPressed: _isUploadingImage ? null : _showAttachmentSheet,
          ),
          const SizedBox(width: 4),
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              minLines: 1,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              onSubmitted: (_) => _send(),
              decoration: InputDecoration(
                hintText: widget.isChatWithCs
                    ? 'Tulis pesan bantuan...'
                    : (widget.isDriverRole
                          ? 'Tulis pesan untuk penumpang...'
                          : 'Tulis pesan untuk driver...'),
                hintStyle: TextStyle(color: Colors.grey[400], fontSize: 13),
                filled: true,
                fillColor: const Color(0xFFF3F4F6),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
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
