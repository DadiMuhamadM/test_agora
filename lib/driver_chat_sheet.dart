import 'package:agora_chat_sdk/agora_chat_sdk.dart';
import 'package:flutter/material.dart';
import 'call_screen.dart';
import 'core/res/colors.dart';
import 'main.dart'; // Mengambil AgoraConfig

/// Model pesan chat shuttle
class DriverChatMessage {
  final String? msgId;
  final String text;
  final bool isMe;
  final DateTime time;
  bool isRead;
  bool isDelivered;

  DriverChatMessage({
    this.msgId,
    required this.text,
    required this.isMe,
    required this.time,
    this.isRead = false,
    this.isDelivered = false,
  });
}

/// Fungsi pembuka bottom sheet chat room
/// Panggil dari LokasiDriverScreen:
/// showDriverChatSheet(context, driverName: 'Pak Dika', targetUserId: 'dhika-driver', currentUserId: 'dhadi-cust');
Future<void> showDriverChatSheet(
  BuildContext context, {
  required String driverName,
  String? targetUserId,
  String? currentUserId,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => DriverChatSheet(
      driverName: driverName,
      targetUserId: targetUserId,
      currentUserId: currentUserId,
    ),
  );
}

class DriverChatSheet extends StatefulWidget {
  final String driverName;
  final String? targetUserId;
  final String? currentUserId;

  const DriverChatSheet({
    super.key,
    required this.driverName,
    this.targetUserId,
    this.currentUserId,
  });

  @override
  State<DriverChatSheet> createState() => _DriverChatSheetState();
}

class _DriverChatSheetState extends State<DriverChatSheet> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  final _scrollController = ScrollController();

  static const _quickReplies = [
    'Saya sudah di lokasi jemput',
    'Mohon tunggu sebentar',
    'Posisi Anda di mana?',
    'Terima kasih',
  ];

  // Pesan chat terhubung dengan Agora
  final List<DriverChatMessage> _messages = [];

  late String _currentUserId;
  late String _targetUserId;

  @override
  void initState() {
    super.initState();
    // Default user ID jika tidak di-pass dari widget
    _currentUserId = widget.currentUserId ?? AgoraConfig.penumpangId;
    _targetUserId = widget.targetUserId ?? AgoraConfig.driverId;

    _loadAgoraHistory();
    _setupAgoraListener();
  }

  @override
  void dispose() {
    // Bersihkan listener event saat bottom sheet ditutup
    ChatClient.getInstance.chatManager.removeEventHandler(
      "DRIVER_CHAT_SHEET_HANDLER",
    );
    _controller.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ==========================================================================
  // MEMUAT RIWAYAT CHAT DARI AGORA CHAT SDK (LOKAL & SERVER)
  // ==========================================================================
  Future<void> _loadAgoraHistory() async {
    debugPrint("[AGORA CHAT] 📥 Memuat riwayat chat dengan $_targetUserId...");
    try {
      final conversation = await ChatClient.getInstance.chatManager
          .getConversation(_targetUserId, createIfNeed: true);

      List<ChatMessage> list = [];

      if (conversation != null) {
        list = await conversation.loadMessages(
          loadCount: 50,
          direction: ChatSearchDirection.Up,
        );
      }

      // Jika memori lokal kosong, ambil dari server Agora
      if (list.isEmpty) {
        try {
          final result = await ChatClient.getInstance.chatManager
              .fetchHistoryMessagesByOption(
                _targetUserId,
                ChatConversationType.Chat,
                options: FetchMessageOptions(
                  direction: ChatSearchDirection.Up,
                  needSave: true,
                ),
                pageSize: 50,
              );
          list = result.data;
        } catch (serverErr) {
          debugPrint("[AGORA CHAT] Fetch dari server: $serverErr");
        }
      }

      // Urutkan secara kronologis (dari terlama ke terbaru)
      list.sort((a, b) {
        final tA = a.serverTime > 0 ? a.serverTime : a.localTime;
        final tB = b.serverTime > 0 ? b.serverTime : b.localTime;
        return tA.compareTo(tB);
      });

      List<DriverChatMessage> history = [];
      for (var msg in list) {
        if (msg.body.type == MessageType.TXT) {
          // Saring jika pesan adalah metadata sinyal telepon
          if (msg.attributes != null &&
              msg.attributes!["action"] == "CALL_INVITE") {
            continue;
          }
          final body = msg.body as ChatTextMessageBody;
          final isMe = msg.from == _currentUserId;
          final timestamp = msg.serverTime > 0 ? msg.serverTime : msg.localTime;

          history.add(
            DriverChatMessage(
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
      debugPrint("[AGORA CHAT] Gagal memuat riwayat: $e");
    }
  }

  // ==========================================================================
  // SETUP LISTENER PESAN & SINYAL MASUK REAL-TIME
  // ==========================================================================
  void _setupAgoraListener() {
    ChatClient.getInstance.chatManager.addEventHandler(
      "DRIVER_CHAT_SHEET_HANDLER",
      ChatEventHandler(
        onMessagesReceived: (List<ChatMessage> messages) {
          for (var msg in messages) {
            if (msg.from?.trim().toLowerCase() ==
                _targetUserId.trim().toLowerCase()) {
              // 1. Cek apakah ini sinyal panggilan telepon
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
                _showIncomingCallDialog(
                  caller: widget.driverName,
                  channelId: channelId,
                  isVideo: isVideo,
                );
                continue;
              }

              // 2. Pesan teks obrolan biasa
              if (msg.body.type == MessageType.TXT) {
                final body = msg.body as ChatTextMessageBody;
                final timestamp = msg.localTime;

                if (mounted) {
                  setState(() {
                    _messages.add(
                      DriverChatMessage(
                        text: body.content,
                        isMe: false,
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

  // ==========================================================================
  // MENGIRIM PESAN TEKS KE AGORA
  // ==========================================================================
  Future<void> _send([String? quickText]) async {
    final text = (quickText ?? _controller.text).trim();
    if (text.isEmpty) return;

    debugPrint("[AGORA CHAT] Mengirim pesan: \"$text\" ke $_targetUserId");

    final msg = ChatMessage.createTxtSendMessage(
      targetId: _targetUserId,
      content: text,
    );

    try {
      await ChatClient.getInstance.chatManager.sendMessage(msg);

      if (mounted) {
        setState(() {
          _messages.add(
            DriverChatMessage(text: text, isMe: true, time: DateTime.now()),
          );
        });
        _controller.clear();
        _scrollToBottom();
      }
    } catch (e) {
      debugPrint("[AGORA CHAT] Gagal mengirim pesan: $e");
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text("Gagal kirim pesan: $e")));
      }
    }
  }

  // ==========================================================================
  // MEMULAI PANGGILAN SUARA / VIDEO (AGORA RTC)
  // ==========================================================================
  Future<void> _startCall({required bool isVideo}) async {
    final channelId = AgoraConfig.channelId.isNotEmpty
        ? AgoraConfig.channelId
        : "shuttle_${_currentUserId}_${_targetUserId}";

    debugPrint("[AGORA CALL] Memulai panggilan ke $_targetUserId...");

    // 1. Kirim sinyal panggilan masuk via Agora Chat SDK
    final callMsg = ChatMessage.createTxtSendMessage(
      targetId: _targetUserId,
      content: isVideo
          ? "📹 Panggilan Video Masuk..."
          : "📞 Panggilan Suara Masuk...",
    );
    callMsg.attributes = {
      "action": "CALL_INVITE",
      "channelId": channelId,
      "isVideo": isVideo,
      "caller": _currentUserId,
      "callTime": DateTime.now().millisecondsSinceEpoch,
    };

    try {
      await ChatClient.getInstance.chatManager.sendMessage(callMsg);
    } catch (e) {
      debugPrint("[AGORA CALL] Gagal kirim sinyal telepon: $e");
    }

    // 2. Buka layar CallScreen
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

  // Dialog pop-up panggilan masuk jika ada panggilan saat bottom sheet terbuka
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
                  isVideo ? "Panggilan Video Masuk" : "Panggilan Suara Masuk",
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

  void _fillQuickReply(String text) {
    _controller.text = text;
    _controller.selection = TextSelection.fromPosition(
      TextPosition(offset: text.length), // kursor di akhir teks
    );
    _focusNode.requestFocus(); // buka keyboard
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
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            _buildHeader(context),
            const Divider(height: 1),
            Expanded(child: _buildMessageList()),
            _buildQuickReplies(),
            _buildInputBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: COLORS.primary.withValues(alpha: 0.1),
                child: const Icon(Icons.person, color: COLORS.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.driverName,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
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
                        const SizedBox(width: 6),
                        Text(
                          'Driver • Online',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              // Tombol Voice Call
              IconButton(
                tooltip: "Panggilan Suara",
                onPressed: () => _startCall(isVideo: false),
                icon: const Icon(Icons.phone, color: COLORS.primary),
              ),
              // Tombol Video Call
              IconButton(
                tooltip: "Panggilan Video",
                onPressed: () => _startCall(isVideo: true),
                icon: const Icon(Icons.videocam, color: COLORS.primary),
              ),
              // Tombol Tutup Sheet
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMessageList() {
    if (_messages.isEmpty) {
      return Center(
        child: Text(
          'Belum ada pesan.\nMulai percakapan dengan driver.',
          textAlign: TextAlign.center,
          style: TextStyle(color: Colors.grey[500]),
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

  Widget _buildBubble(DriverChatMessage msg) {
    final isMe = msg.isMe;

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.72,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isMe ? COLORS.primary : Colors.grey[200],
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(14),
            topRight: const Radius.circular(14),
            bottomLeft: Radius.circular(isMe ? 14 : 2),
            bottomRight: Radius.circular(isMe ? 2 : 14),
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
                  color: isMe ? Colors.white : Colors.black87,
                  fontSize: 14,
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
                    color: isMe ? Colors.white70 : Colors.grey[600],
                  ),
                ),
                if (isMe) ...[
                  const SizedBox(width: 4),
                  if (msg.isRead)
                    const Icon(
                      Icons.done_all,
                      size: 13,
                      color: Color(0xFF00E5FF), // Ceklis 2 Biru WhatsApp
                    )
                  else if (msg.isDelivered)
                    const Icon(
                      Icons.done_all,
                      size: 13,
                      color: Colors.white70, // Ceklis 2 Abu-abu
                    )
                  else
                    const Icon(
                      Icons.done,
                      size: 13,
                      color: Colors.white70, // Ceklis 1 Terkirim
                    ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickReplies() {
    return SizedBox(
      height: 40,
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
            onPressed: () => _fillQuickReply(_quickReplies[i]),
          );
        },
      ),
    );
  }

  Widget _buildInputBar() {
    return SafeArea(
      top: false,
      child: Padding(
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
                  hintText: 'Tulis pesan...',
                  filled: true,
                  fillColor: Colors.grey[100],
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
      ),
    );
  }
}
