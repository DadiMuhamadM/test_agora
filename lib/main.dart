import 'dart:async';
import 'package:agora_chat_sdk/agora_chat_sdk.dart';
import 'package:flutter/material.dart';
import 'call_screen.dart';
import 'core/res/colors.dart';
import 'driver_chat_room_screen.dart';

void main() {
  runApp(const MyApp());
}

// ============================================================================
// 1. KONFIGURASI AGORA & DATA AKUN TESTING
// (1 DRIVER, 2 PENUMPANG, DAN 1 CUSTOMER SERVICE)
// ============================================================================
class AgoraConfig {
  static const String appKey = "61200084352#200118764";

  // App ID Agora untuk RTC Engine (Voice Call & Video Call)
  static const String rtcAppId = "e36d7215a784494c817ed24da9b9c133";
  static const String rtcToken =
      "007eJxTYKj+skFdxl7z2LciuTz5gzGr80wuz+uTvXtxT/ZOrg3hG2UVGFKNzVLMjQxNE80tTEwsTZItDM1TU4xMUhItkyyTDY2NNfteZjUEMjLwsPexMjEwgiGYz5CSmpuvm5yRmJeXmsPAwASXYWEwNDAwBABICiLu";

  // 1. Akun Driver (Pak Dika - HiAce)
  static String driverId = "dhika-driver";
  static String driverToken =
      "007eJxTYHgfezX5mY6p7IU90d8U3L/s//LEWdu1z2z7YgcP+y93pqQpMKQam6WYGxmaJppbmJhYmiRbGJqnphiZpCRaJlkmGxobC/a9zGoIZGRIcXZlYWRgZWAEQhBfhcEsKSU1xSzFQDfFKDFZ19AwzVA3KcnSXNcyyczUxDAx0dg4OQUA99Qomw==";
  // 2. Akun Penumpang 1 (Dadi M)
  static String penumpang1Id = "dhadi-cust";
  static String penumpang1Token =
      "007eJxTYFizOCeq0Zt7XsYP1391dWfsuhYbFcwUPJZ7ky/DUv37IykFhlRjsxRzI0PTRHMLExNLk2QLQ/PUFCOTlETLJMtkQ2Pjz70vsxoCGRkKBfRZGBlYGRiBEMRXYTA3TTZKSkw10E0xSkzWNTRMM9RNSjE10DUwtEhMNjIxszSzsAAAZR4m5w==";

  // 3. Akun Penumpang 2 (Arief)
  static String penumpang2Id = "asep";
  static String penumpang2Token =
      "007eJxTYGD7vTi+qnHe5a7vvr/YX0/sW7sj1Wrh/JDNL469Oh91L+uoAkOqsVmKuZGhaaK5hYmJpUmyhaF5aoqRSUqiZZJlsqGxsfLEl1kNgYwMRhXdDIwMrEDMyADiqzCYJacmGRukGOimmJta6hoaphnqWhgZpOomG1tYJKaaGySmWloCAOgQKpA=";

  // 4. Akun Customer Service (CS Sunjaya Shuttle)
  static String csId = "ujag";
  static String csToken =
      "007eJxTYGAMvKLN9txXxGmSlpPVgiOMxwOUeoJY3p/VvSbievPCS14FhlRjsxRzI0PTRHMLExNLk2QLQ/PUFCOTlETLJMtkQ2PjTxNeZjUEMjJcubyMgZGBFYgZGUB8FQYzwySDpBRzA90Uc1NLXUPDNENdS1MTQ13TNEszc/M0AwNjI0MAlBUlcQ==";

  // Kompatibilitas dengan kode sebelumnya
  static String get driver1Id => driverId;
  static String get driver1Token => driverToken;
  static String get penumpangId => penumpang1Id;
  static String get penumpangToken => penumpang1Token;

  // Channel RTC yang digunakan untuk pengujian (harus cocok dengan nama channel saat generate RTC Token)
  static const String channelId = "demo-channel";
}

// TESTING DADI

// class AgoraConfig {
//   static const String appKey = "61200085852#200121159";

//   // App ID Agora untuk RTC Engine (Voice Call & Video Call)
//   static const String rtcAppId = "9e7904fefbc14af987b6a34f08b23383";
//   static const String rtcToken =
//       "007eJxTYFjdlW59Pi3hEfPvl4suSd1ZaF+ts1/dgIdrzU2mdfe38+cqMFimmlsamKSlpiUlG5okpllamCeZJRqbpBlYJBkZG1sY94S9zGoIZGSId57MzMgAgSA+P0NJanFJZl66bnJGYl5eag4DAwDg0iPR";

//   // 1. Akun Driver (Pak Dika - HiAce)
//   static String driverId = "ibnu-driver";
//   static String driverToken =
//       "007eJxTYLBPYVNfvvq1y6LMx2laoolMjZN2ue5NPXzKlCMhgecwz1YFBstUc0sDk7TUtKRkQ5PENEsL8ySzRGOTNAOLJCNjYwvjtIiXWQ2BjAx9hv4sjAysDIxACOKrMFgkpiSnWiYZ6KaYG1voGhqmGeomGhok6RolASVM0szNUgwtAZcgJZA=";
//   // 2. Akun Penumpang 1 (Dadi M)
//   static String penumpang1Id = "oding-cust";
//   static String penumpang1Token =
//       "007eJxTYLgbcYghYNblpug1LfdWTLIuCF408dYyH4OKyHw2Lv4H7t8UGCxTzS0NTNJS05KSDU0S0ywtzJPMEo1N0gwskoyMjS2MHSJeZjUEMjKs33WHhZGBlYERCEF8FQZzy5Q0Q3MDA90Uc2MLXUPDNEPdJIM0C10D47SU5CTjFHMLA0sAo0Mn3A==";

//   // 3. Akun Penumpang 2 (Arief)
//   static String penumpang2Id = "arief-cust";
//   static String penumpang2Token =
//       "007eJxTYHCdx5vkd3vXsemzXqiuSPY7cXCjo+suwQZ7S437Hf8rFZYpMFimmlsamKSlpiUlG5okpllamCeZJRqbpBlYJBkZG1sY90a8zGoIZGSYsDOflZGBlYERCEF8FQYLYwvzZLMUA90Uc2MLXUPDNENdyxRDY10jS5OkxDRTAwsDA0MAsGYnaA==";

//   // 4. Akun Customer Service (CS Sunjaya Shuttle)
//   static String csId = "maya-cs";
//   static String csToken =
//       "007eJxTYNj9ycL9xEy51ws9+DM+SzIde7vw9LHqW906VZFL+970m2spMFimmlsamKSlpiUlG5okpllamCeZJRqbpBlYJBkZG1sYr4l4mdUQyMigKPOIiZGBlYERCEF8FQaLtDQLcwMTA90Uc2MLXUPDNENdCyMDC90UYxPj5BQjMxMjQwsABQ4ntw==";

//   // Kompatibilitas dengan kode sebelumnya
//   static String get driver1Id => driverId;
//   static String get driver1Token => driverToken;
//   static String get penumpangId => penumpang1Id;
//   static String get penumpangToken => penumpang1Token;

//   // Channel RTC yang digunakan untuk pengujian (harus cocok dengan nama channel saat generate RTC Token)
//   static const String channelId = "testing-channel";
// }

enum UserType { driver, customer, cs }

/// Model Akun Shuttle untuk Pengujian Simulator
class ShuttleUser {
  final String id;
  final String name;
  final UserType type;
  final String subtitle;
  final String tripTitle;
  final String assignedDriverId; // Jika akun adalah penumpang
  final List<String> assignedPassengerIds; // Jika akun adalah driver
  String token;

  ShuttleUser({
    required this.id,
    required this.name,
    required this.type,
    required this.subtitle,
    required this.tripTitle,
    this.assignedDriverId = "",
    this.assignedPassengerIds = const [],
    required this.token,
  });

  bool get isDriver => type == UserType.driver;
  bool get isCustomer => type == UserType.customer;
  bool get isCs => type == UserType.cs;
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Sunjaya Shuttle Simulator',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: COLORS.primary),
        scaffoldBackgroundColor: const Color(0xFFF4F6F9),
        useMaterial3: true,
      ),
      home: const ShuttleTestingDashboard(),
    );
  }
}

/// ============================================================================
/// DASHBOARD TESTING SHUTTLE
/// (1 DRIVER, 2 PENUMPANG, DAN 1 CUSTOMER SERVICE)
/// ============================================================================
class ShuttleTestingDashboard extends StatefulWidget {
  const ShuttleTestingDashboard({super.key});

  @override
  State<ShuttleTestingDashboard> createState() =>
      _ShuttleTestingDashboardState();
}

class _ShuttleTestingDashboardState extends State<ShuttleTestingDashboard> {
  late List<ShuttleUser> _allUsers;
  late ShuttleUser _currentUser;

  bool _isLoggedIn = false;
  bool _isSwitching = false;

  // Notifikasi In-App & Unread Message Badges
  final Map<String, int> _unreadCounts = {};
  OverlayEntry? _currentNotificationOverlay;
  Timer? _notificationDismissTimer;
  String? _activeChatUserId; // ID user yang room chat-nya sedang aktif dibuka

  // Percakapan aktif untuk tampilan CS Helpdesk dinamis
  List<ChatConversation> _csConversations = [];
  Map<String, String> _lastMessages = {};
  bool _isLoadingCsConversations = false;

  @override
  void initState() {
    super.initState();
    _initTestingAccounts();
    _currentUser = _allUsers[0]; // Default awal: Pak Dika (Driver)
    _initAgoraSDK();
  }

  void _initTestingAccounts() {
    _allUsers = [
      // 🚗 1 DRIVER
      ShuttleUser(
        id: AgoraConfig.driverId,
        name: "Pak Dhika (Driver HiAce)",
        type: UserType.driver,
        subtitle: "Toyota HiAce • D 1984 ABC",
        tripTitle: "Bandung - Jakarta (08:00 WIB)",
        assignedPassengerIds: [
          AgoraConfig.penumpang1Id,
          AgoraConfig.penumpang2Id,
        ],
        token: AgoraConfig.driverToken,
      ),

      // 👤 2 PENUMPANG
      ShuttleUser(
        id: AgoraConfig.penumpang1Id,
        name: "Dadi",
        type: UserType.customer,
        subtitle: "Titik:  Mall PVJ • Kursi 1A",
        tripTitle: "Bandung - Jakarta (08:00 WIB)",
        assignedDriverId: AgoraConfig.driverId,
        token: AgoraConfig.penumpang1Token,
      ),
      ShuttleUser(
        id: AgoraConfig.penumpang2Id,
        name: "Mang Arief",
        type: UserType.customer,
        subtitle: "Titik: Hotel Homann • Kursi 1B",
        tripTitle: "Bandung - Jakarta (08:00 WIB)",
        assignedDriverId: AgoraConfig.driverId,
        token: AgoraConfig.penumpang2Token,
      ),

      // 🎧 1 CUSTOMER SERVICE (CS)
      ShuttleUser(
        id: AgoraConfig.csId,
        name: "Ujang (CS Sunjaya Shuttle)",
        type: UserType.cs,
        subtitle: "Layanan Bantuan Pelanggan 24 Jam",
        tripTitle: "Pusat Bantuan & Customer Care",
        token: AgoraConfig.csToken,
      ),
    ];
  }

  // ==========================================================================
  // INISIALISASI AGORA CHAT SDK
  // ==========================================================================
  Future<void> _initAgoraSDK() async {
    debugPrint("[AGORA SDK] Inisialisasi Agora Chat SDK...");
    try {
      ChatOptions options = ChatOptions.withAppKey(
        AgoraConfig.appKey,
        autoLogin: false,
      );
      await ChatClient.getInstance.init(options);
      await ChatClient.getInstance.startCallback();

      _setupGlobalMessageAndCallListener();
      await _loginAgora();
    } catch (e) {
      debugPrint("[AGORA SDK] Inisialisasi gagal: $e");
    }
  }

  // ==========================================================================
  // SEGARKAN JUMLAH PESAN BELUM DIBACA (UNREAD BADGE)
  // ==========================================================================
  Future<void> _refreshUnreadCounts() async {
    try {
      final Map<String, int> counts = {};
      for (final user in _allUsers) {
        if (user.id == _currentUser.id) continue;
        final conv = await ChatClient.getInstance.chatManager.getConversation(
          user.id,
        );
        if (conv != null) {
          final unread = await conv.unreadCount();
          counts[user.id] = unread;
        } else {
          counts[user.id] = 0;
        }
      }
      if (mounted) {
        setState(() {
          _unreadCounts.clear();
          _unreadCounts.addAll(counts);
        });
      }
    } catch (e) {
      debugPrint("[AGORA UNREAD] Gagal memperbarui unread count: $e");
    }
  }

  // ==========================================================================
  // HELPER MENCARI DATA PENGGUNA BERDASARKAN AGORA USER ID
  // ==========================================================================
  ShuttleUser _getUserById(String id) {
    return _allUsers.firstWhere(
      (u) => u.id == id,
      orElse: () => ShuttleUser(
        id: id,
        name: id,
        type: UserType.customer,
        subtitle: "Pengguna Shuttle",
        tripTitle: "Layanan Pelanggan",
        token: "",
      ),
    );
  }

  // ==========================================================================
  // MEMUAT PERCAKAPAN AKTIF UNTUK SISI CUSTOMER SERVICE (CS)
  // ==========================================================================
  Future<void> _loadCsConversations() async {
    if (!mounted) return;
    setState(() => _isLoadingCsConversations = true);
    try {
      final convs = await ChatClient.getInstance.chatManager
          .loadAllConversations();
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
      debugPrint("[CS INBOX] Gagal memuat percakapan: $e");
      if (mounted) {
        setState(() => _isLoadingCsConversations = false);
      }
    }
  }

  // ==========================================================================
  // HAPUS PERCAKAPAN & RIWAYAT CHAT CS DARI AGORA SDK
  // ==========================================================================
  Future<void> _deleteCsConversation(String conversationId) async {
    try {
      await ChatClient.getInstance.chatManager.deleteConversation(
        conversationId,
        deleteMessages: true, // hapus riwayat pesan lokalnya juga
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
      debugPrint("[CS INBOX] Gagal menghapus percakapan: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Gagal menghapus percakapan: $e")),
        );
      }
    }
  }

  void _confirmDeleteCsConversation(ShuttleUser targetUser) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text("Hapus Riwayat Chat?"),
        content: Text(
          "Tiket bantuan dari ${targetUser.name} akan diselesaikan dan riwayat percakapan akan dihapus dari antrean CS Anda.",
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
              await _deleteCsConversation(targetUser.id);
            },
            child: const Text("Hapus"),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // LOGIN KE AGORA CHAT DENGAN USER AKTIF
  // ==========================================================================
  Future<void> _loginAgora() async {
    if (_currentUser.token.isEmpty) {
      debugPrint(
        "[AGORA LOGIN] ⚠️ Token untuk ${_currentUser.id} belum diisi. Silakan isi token melalui menu Kelola Token.",
      );
      if (mounted) setState(() => _isLoggedIn = false);
      return;
    }

    debugPrint("[AGORA LOGIN] Melakukan login sebagai ${_currentUser.id}...");
    try {
      try {
        await ChatClient.getInstance.logout(true);
      } catch (_) {}

      await ChatClient.getInstance.loginWithToken(
        _currentUser.id,
        _currentUser.token,
      );

      if (mounted) {
        setState(() {
          _isLoggedIn = true;
        });
      }
      debugPrint("[AGORA LOGIN] ✅ Berhasil login sebagai ${_currentUser.id}");
      await _refreshUnreadCounts();
      if (_currentUser.isCs) {
        await _loadCsConversations();
      }
    } catch (e) {
      debugPrint("[AGORA LOGIN] ❌ Gagal login: $e");
      if (mounted) {
        setState(() {
          _isLoggedIn = false;
        });
      }
    }
  }

  // ==========================================================================
  // GANTI AKUN PENGGUNA (SWITCH USER)
  // ==========================================================================
  Future<void> _switchUser(ShuttleUser newUser) async {
    if (_currentUser.id == newUser.id) return;

    setState(() {
      _isSwitching = true;
      _currentUser = newUser;
      _isLoggedIn = false;
    });

    await _loginAgora();

    if (mounted) {
      setState(() {
        _isSwitching = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Berhasil beralih akun: ${newUser.name}"),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  // ==========================================================================
  // GLOBAL LISTENER PESAN MASUK & PANGGILAN (KETIKA BERADA DI DASHBOARD)
  // ==========================================================================
  void _setupGlobalMessageAndCallListener() {
    ChatClient.getInstance.chatManager.removeEventHandler("GLOBAL_APP_HANDLER");
    ChatClient.getInstance.chatManager.addEventHandler(
      "GLOBAL_APP_HANDLER",
      ChatEventHandler(
        onMessagesReceived: (List<ChatMessage> messages) {
          for (var msg in messages) {
            // A. PANGGILAN TELEPON MASUK
            if (msg.attributes != null &&
                msg.attributes!["action"] == "CALL_INVITE") {
              // Validasi batas waktu panggilan (maksimal 35 detik dari waktu kirim)
              // Mencegah panggilan lama / offline message memicu dering saat baru buka aplikasi
              final callTime =
                  (msg.attributes!["callTime"] as int?) ??
                  (msg.serverTime > 0 ? msg.serverTime : msg.localTime);
              if (callTime > 0) {
                final ageInSeconds =
                    (DateTime.now().millisecondsSinceEpoch - callTime) / 1000;
                if (ageInSeconds > 35) {
                  debugPrint(
                    "[GLOBAL CALL] ⚠️ Panggilan lama/offline terdeteksi (${ageInSeconds.toStringAsFixed(1)}s lalu) dari ${msg.from}. Pop-up dering diabaikan.",
                  );
                  continue;
                }
              }

              final channelId =
                  msg.attributes!["channelId"] as String? ?? "demo-channel";
              final isVideo = msg.attributes!["isVideo"] as bool? ?? false;
              final callerId = msg.from ?? "";

              // Cari nama penelepon
              String callerName =
                  msg.attributes!["callerName"] as String? ?? "";
              if (callerName.isEmpty) {
                final matched = _allUsers.where((u) => u.id == callerId);
                callerName = matched.isNotEmpty ? matched.first.name : callerId;
              }

              _showIncomingCallDialog(
                caller: callerName,
                channelId: channelId,
                isVideo: isVideo,
              );
              continue;
            }

            // B. PESAN CHAT MASUK (TEKS ATAU GAMBAR) SAAT DI DASHBOARD
            final senderId = msg.from ?? "";
            if (senderId.isEmpty || senderId == _currentUser.id) continue;

            // Jangan munculkan banner melayang jika user sedang membuka room chat lawan bicara ini
            if (_activeChatUserId != null &&
                _activeChatUserId!.trim().toLowerCase() ==
                    senderId.trim().toLowerCase()) {
              continue;
            }

            final matched = _allUsers.where((u) => u.id == senderId);
            final senderUser = matched.isNotEmpty
                ? matched.first
                : ShuttleUser(
                    id: senderId,
                    name: senderId,
                    type: UserType.customer,
                    subtitle: "Pengguna Shuttle",
                    tripTitle: "",
                    token: "",
                  );

            String previewText = "";
            if (msg.body.type == MessageType.TXT) {
              final body = msg.body as ChatTextMessageBody;
              previewText = body.content;
            } else if (msg.body.type == MessageType.IMAGE) {
              previewText = "📷 Mengirim sebuah foto";
            } else {
              previewText = "Mengirim pesan baru";
            }

            // Update badge lokal
            if (mounted) {
              setState(() {
                _unreadCounts[senderId] = (_unreadCounts[senderId] ?? 0) + 1;
              });
              if (_currentUser.isCs) {
                _loadCsConversations();
              }
            }

            // Tampilkan In-App Floating Notification Banner di atas layar
            _showInAppNotificationBanner(
              senderUser: senderUser,
              messagePreview: previewText,
            );
          }
        },
      ),
    );
  }

  // ==========================================================================
  // IN-APP FLOATING NOTIFICATION BANNER (MUNCUL DI BAGIAN ATAS LAYAR)
  // ==========================================================================
  void _showInAppNotificationBanner({
    required ShuttleUser senderUser,
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
          top: MediaQuery.of(context).padding.top + 8,
          left: 12,
          right: 12,
          child: Material(
            color: Colors.transparent,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: -60.0, end: 0.0),
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
                  _notificationDismissTimer?.cancel();
                  if (entry.mounted) {
                    try {
                      entry.remove();
                    } catch (_) {}
                  }
                  _currentNotificationOverlay = null;
                  _openChatRoom(senderUser);
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E1E2C),
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                    ],
                    border: Border.all(color: Colors.white24, width: 1),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: senderUser.isCs
                            ? Colors.purple.shade600
                            : (senderUser.isDriver
                                  ? Colors.blue.shade600
                                  : Colors.green.shade600),
                        child: Icon(
                          senderUser.isCs
                              ? Icons.support_agent
                              : (senderUser.isDriver
                                    ? Icons.drive_eta
                                    : Icons.person),
                          color: Colors.white,
                          size: 20,
                        ),
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
                                    senderUser.name,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
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
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(
                          Icons.close,
                          color: Colors.white60,
                          size: 18,
                        ),
                        onPressed: () {
                          _notificationDismissTimer?.cancel();
                          if (entry.mounted) {
                            try {
                              entry.remove();
                            } catch (_) {}
                          }
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

    // Otomatis sembunyikan banner setelah 4 detik (jika belum di-tap/close)
    _notificationDismissTimer = Timer(const Duration(seconds: 4), () {
      if (_currentNotificationOverlay == entry && entry.mounted) {
        try {
          entry.remove();
        } catch (_) {}
        _currentNotificationOverlay = null;
      }
    });
  }

  bool _isCallDialogShowing = false;

  void _showIncomingCallDialog({
    required String caller,
    required String channelId,
    required bool isVideo,
  }) {
    if (!mounted || _isCallDialogShowing) return;
    _isCallDialogShowing = true;

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
                  textAlign: TextAlign.center,
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
                        _isCallDialogShowing = false;
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
                          _isCallDialogShowing = false;
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
    );
  }

  // ==========================================================================
  // MEMULAI PANGGILAN LANGSUNG DARI HALAMAN UTAMA KE TARGET USER
  // ==========================================================================
  Future<void> _startDirectCall({
    required ShuttleUser targetUser,
    required bool isVideo,
  }) async {
    final ids = [_currentUser.id, targetUser.id]..sort();
    final channelId = AgoraConfig.channelId.isNotEmpty
        ? AgoraConfig.channelId
        : "shuttle_${ids[0]}_${ids[1]}";

    final callMsg = ChatMessage.createTxtSendMessage(
      targetId: targetUser.id,
      content: isVideo
          ? "📹 Panggilan Video Masuk..."
          : "📞 Panggilan Suara Masuk...",
    );
    callMsg.attributes = {
      "action": "CALL_INVITE",
      "channelId": channelId,
      "isVideo": isVideo,
      "caller": _currentUser.id,
      "callerName": _currentUser.name,
      "callTime": DateTime.now().millisecondsSinceEpoch,
    };

    try {
      await ChatClient.getInstance.chatManager.sendMessage(callMsg);
    } catch (e) {
      debugPrint("[AGORA CALL] Gagal kirim sinyal telepon: $e");
    }

    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CallScreen(
            channelId: channelId,
            isVideoCall: isVideo,
            targetName: targetUser.name,
          ),
        ),
      );
    }
  }

  // Buka Room Chat dengan Target User
  void _openChatRoom(ShuttleUser targetUser) async {
    _activeChatUserId = targetUser
        .id; // Tandai bahwa user sedang membuka chat dengan targetUser ini
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatDriverScreen(
          driverName: targetUser.name,
          driverUserId: targetUser.id,
          customerUserId: _currentUser.id,
          customerToken: _currentUser.token,
          isDriverRole: _currentUser.isDriver,
          isCsRole: _currentUser.isCs,
          isChatWithCs: targetUser.isCs,
          targetSubtitle: targetUser.subtitle,
        ),
      ),
    );
    _activeChatUserId = null; // Reset saat kembali ke dashboard
    // Saat kembali ke dashboard, segarkan jumlah pesan belum dibaca
    await _refreshUnreadCounts();
    if (_currentUser.isCs) {
      await _loadCsConversations();
    }
  }

  // ==========================================================================
  // WIDGET BADGE INDIKATOR PESAN BELUM DIBACA (UNREAD BADGE)
  // ==========================================================================
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

  @override
  void dispose() {
    ChatClient.getInstance.chatManager.removeEventHandler("GLOBAL_APP_HANDLER");
    _notificationDismissTimer?.cancel();
    try {
      _currentNotificationOverlay?.remove();
    } catch (_) {}
    super.dispose();
  }

  // ==========================================================================
  // BUILD UTAMA WIDGET
  // ==========================================================================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          "Sunjaya Shuttle Testing",
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        elevation: 0.5,
        actions: [
          // Indikator Status Agora
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: _isLoggedIn ? Colors.green.shade50 : Colors.orange.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _isLoggedIn ? Colors.green : Colors.orange,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  _isLoggedIn ? Icons.cloud_done : Icons.cloud_off,
                  size: 14,
                  color: _isLoggedIn ? Colors.green : Colors.orange,
                ),
                const SizedBox(width: 4),
                Text(
                  _isLoggedIn ? "Terhubung" : "Offline",
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: _isLoggedIn
                        ? Colors.green.shade700
                        : Colors.orange.shade700,
                  ),
                ),
              ],
            ),
          ),
          // Tombol Kelola Token
          IconButton(
            tooltip: "Kelola Token Akun",
            icon: const Icon(Icons.key, color: Colors.black87),
            onPressed: _showTokenManagerDialog,
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: _isSwitching
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text("Beralih akun Agora..."),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // CARD 1: AKUN AKTIF SAAT INI + TOMBOL GANTI AKUN
                  _buildActiveAccountCard(),
                  const SizedBox(height: 16),

                  // CARD 2: TAMPILAN SESUAI ROLE (DRIVER / PENUMPANG / CS)
                  if (_currentUser.isDriver)
                    _buildDriverView()
                  else if (_currentUser.isCustomer)
                    _buildCustomerView()
                  else if (_currentUser.isCs)
                    _buildCsView(),
                ],
              ),
            ),
    );
  }

  // ==========================================================================
  // WIDGET CARD AKUN AKTIF DENGAN TOMBOL SWITCH AKUN
  // ==========================================================================
  Widget _buildActiveAccountCard() {
    Color badgeColor;
    String roleLabel;
    IconData roleIcon;

    if (_currentUser.isDriver) {
      badgeColor = Colors.blue;
      roleLabel = "DRIVER SHUTTLE";
      roleIcon = Icons.drive_eta;
    } else if (_currentUser.isCs) {
      badgeColor = Colors.purple;
      roleLabel = "CUSTOMER SERVICE";
      roleIcon = Icons.support_agent;
    } else {
      badgeColor = Colors.green;
      roleLabel = "PENUMPANG";
      roleIcon = Icons.person;
    }

    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      elevation: 0,
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: badgeColor.withOpacity(0.12),
                  child: Icon(roleIcon, size: 30, color: badgeColor),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: badgeColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              roleLabel,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: badgeColor,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            "ID: ${_currentUser.id}",
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _currentUser.name,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        _currentUser.subtitle,
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            // Tombol Switcher Akun
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: COLORS.primary),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: _showAccountSwitcherBottomSheet,
                icon: const Icon(Icons.swap_horiz, color: COLORS.primary),
                label: const Text(
                  "Ganti Akun Demo (Driver / Penumpang / CS)",
                  style: TextStyle(
                    color: COLORS.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================================
  // TAMPILAN SISI DRIVER: MANIFEST DAFTAR PENJEMPUTAN PENUMPANG (2 ORANG)
  // ==========================================================================
  Widget _buildDriverView() {
    final assignedPassengers = _allUsers
        .where(
          (u) =>
              u.isCustomer && _currentUser.assignedPassengerIds.contains(u.id),
        )
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Info Trip Driver
        Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.route, color: COLORS.primary, size: 30),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Jadwal Penjemputan Driver",
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        _currentUser.tripTitle,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Header Manifest
        Text(
          "Daftar Penumpang Jemputan (${assignedPassengers.length} Orang)",
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),

        // List 2 Penumpang
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: assignedPassengers.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, index) {
            final passenger = assignedPassengers[index];
            return _buildPassengerCardForDriver(passenger, index + 1);
          },
        ),
      ],
    );
  }

  Widget _buildPassengerCardForDriver(ShuttleUser passenger, int seatNumber) {
    return Card(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 0,
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: Colors.blue.shade50,
                  child: Text(
                    "P$seatNumber",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue.shade800,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              Text(
                                passenger.name,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 8),
                              _buildUnreadBadge(passenger.id),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.amber.shade50,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              "Menunggu Jemputan",
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.amber.shade800,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        passenger.subtitle,
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                      Text(
                        "ID Agora: ${passenger.id}",
                        style: TextStyle(fontSize: 11, color: Colors.grey[400]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                Expanded(
                  flex: 3,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: COLORS.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: () => _openChatRoom(passenger),
                    icon: const Icon(Icons.chat_bubble_outline, size: 16),
                    label: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          "Chat Penumpang",
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if ((_unreadCounts[passenger.id] ?? 0) > 0) ...[
                          const SizedBox(width: 6),
                          CircleAvatar(
                            radius: 9,
                            backgroundColor: Colors.red.shade600,
                            child: Text(
                              "${_unreadCounts[passenger.id]}",
                              style: const TextStyle(
                                fontSize: 10,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.green),
                      foregroundColor: Colors.green,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: () =>
                        _startDirectCall(targetUser: passenger, isVideo: false),
                    icon: const Icon(Icons.phone, size: 16),
                    label: const Text("Voice", style: TextStyle(fontSize: 12)),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: "Video Call",
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.blue.shade50,
                    foregroundColor: Colors.blue.shade800,
                  ),
                  icon: const Icon(Icons.videocam, size: 20),
                  onPressed: () =>
                      _startDirectCall(targetUser: passenger, isVideo: true),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ==========================================================================
  // TAMPILAN SISI PENUMPANG: TIKET SAYA + DRIVER + MENU TANYA CS (PUSAT BANTUAN)
  // ==========================================================================
  Widget _buildCustomerView() {
    final assignedDriver = _allUsers.firstWhere(
      (u) => u.isDriver && u.id == _currentUser.assignedDriverId,
      orElse: () => _allUsers[0],
    );

    final csUser = _allUsers.firstWhere(
      (u) => u.isCs,
      orElse: () => _allUsers.last,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Card Tiket Penumpang
        Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          elevation: 0,
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        "TIKET SHUTTLE #SJ-${_currentUser.id.hashCode.abs().toString().substring(0, 4)}",
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade800,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text(
                        "Driver Menuju Lokasi",
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  _currentUser.tripTitle,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _currentUser.subtitle,
                  style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // 2. Card Info Driver Penjemput
        Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          elevation: 0,
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "DRIVER YANG MENJEMPUT ANDA",
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: COLORS.primary.withOpacity(0.1),
                      child: const Icon(
                        Icons.person,
                        size: 30,
                        color: COLORS.primary,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                assignedDriver.name,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 8),
                              _buildUnreadBadge(assignedDriver.id),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            assignedDriver.subtitle,
                            style: TextStyle(
                              color: Colors.grey[600],
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const Divider(height: 28),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: COLORS.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        onPressed: () => _openChatRoom(assignedDriver),
                        icon: const Icon(Icons.chat_bubble_outline, size: 18),
                        label: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              "Chat Driver",
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            if ((_unreadCounts[assignedDriver.id] ?? 0) >
                                0) ...[
                              const SizedBox(width: 6),
                              CircleAvatar(
                                radius: 9,
                                backgroundColor: Colors.red.shade600,
                                child: Text(
                                  "${_unreadCounts[assignedDriver.id]}",
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.green.shade600,
                        foregroundColor: Colors.white,
                      ),
                      tooltip: "Voice Call Driver",
                      icon: const Icon(Icons.phone, size: 20),
                      onPressed: () => _startDirectCall(
                        targetUser: assignedDriver,
                        isVideo: false,
                      ),
                    ),
                    const SizedBox(width: 4),
                    IconButton.filled(
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.blue.shade700,
                        foregroundColor: Colors.white,
                      ),
                      tooltip: "Video Call Driver",
                      icon: const Icon(Icons.videocam, size: 20),
                      onPressed: () => _startDirectCall(
                        targetUser: assignedDriver,
                        isVideo: true,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // 3. CARD FITUR BARU: PUSAT BANTUAN & TANYA CS (LIVE CHAT CS)
        Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(color: Colors.purple.shade100, width: 1.5),
          ),
          elevation: 0,
          color: Colors.purple.shade50.withOpacity(0.5),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.purple.shade100,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.support_agent,
                        color: Colors.purple.shade800,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                "Pusat Bantuan",
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.purple.shade900,
                                ),
                              ),
                              const SizedBox(width: 8),
                              _buildUnreadBadge(csUser.id),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.green.shade100,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  "24 Jam",
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green.shade800,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            "Ada kendala tiket, jadwal, atau perubahan titik jemput? Hubungi tim CS kami.",
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.purple.shade900.withOpacity(0.7),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purple.shade700,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 0,
                        ),
                        onPressed: () => _openChatRoom(csUser),
                        icon: const Icon(Icons.chat, size: 18),
                        label: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Text(
                              "Live Chat",
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            if ((_unreadCounts[csUser.id] ?? 0) > 0) ...[
                              const SizedBox(width: 6),
                              CircleAvatar(
                                radius: 9,
                                backgroundColor: Colors.red.shade600,
                                child: Text(
                                  "${_unreadCounts[csUser.id]}",
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: Colors.purple.shade700),
                        foregroundColor: Colors.purple.shade800,
                        padding: const EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () =>
                          _startDirectCall(targetUser: csUser, isVideo: false),
                      icon: const Icon(Icons.phone, size: 18),
                      label: const Text("Telepon CS"),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ==========================================================================
  // TAMPILAN SISI CUSTOMER SERVICE (CS HELPDESK DASHBOARD)
  // ==========================================================================
  Widget _buildCsView() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Card Profil & Status CS Helpdesk
        Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          elevation: 0,
          color: Colors.purple.shade800,
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                const CircleAvatar(
                  radius: 28,
                  backgroundColor: Colors.white24,
                  child: Icon(
                    Icons.support_agent,
                    size: 36,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.greenAccent.shade400,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              "LIVE HELPDESK ONLINE",
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _currentUser.name,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const Text(
                        "Melayani Pelanggan Sunjaya Shuttle",
                        style: TextStyle(fontSize: 12, color: Colors.white70),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // 2. Header Kotak Masuk Chat Dinamis
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              "Kotak Masuk Chat (Inbox CS)",
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.purple.shade50,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    "${_csConversations.length} Obrolan Aktif",
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.purple.shade800,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  tooltip: "Segarkan Obrolan",
                  icon: const Icon(Icons.refresh, size: 18),
                  onPressed: _isLoadingCsConversations
                      ? null
                      : _loadCsConversations,
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),

        // 3. Konten Kotak Masuk: Loading / Kosong / Ada Obrolan
        if (_isLoadingCsConversations)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 36),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_csConversations.isEmpty)
          Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 0,
            color: Colors.white,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 36,
                    backgroundColor: Colors.purple.shade50,
                    child: Icon(
                      Icons.mark_chat_unread_outlined,
                      size: 40,
                      color: Colors.purple.shade400,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    "Belum Ada Obrolan Masuk",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Kotak masuk CS saat ini kosong. Saat ada penumpang atau driver yang mengirim chat ke CS, obrolan otomatis akan muncul di antrean ini.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.grey[600],
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.purple.shade50.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.purple.shade100),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 16,
                          color: Colors.purple.shade700,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            "Tip: Anda juga bisa memulai obrolan langsung lewat tombol di bawah.",
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.purple.shade900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _csConversations.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final conv = _csConversations[index];
              final targetUser = _getUserById(conv.id);
              final lastMsg = _lastMessages[conv.id] ?? "Belum ada pesan";
              final unread = _unreadCounts[conv.id] ?? 0;

              return Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
                color: Colors.white,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 22,
                            backgroundColor: targetUser.isDriver
                                ? Colors.blue.shade50
                                : Colors.green.shade50,
                            child: Icon(
                              targetUser.isDriver
                                  ? Icons.directions_bus
                                  : Icons.person,
                              color: targetUser.isDriver
                                  ? Colors.blue.shade800
                                  : Colors.green.shade800,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        targetUser.name,
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 1.5,
                                      ),
                                      decoration: BoxDecoration(
                                        color: targetUser.isDriver
                                            ? Colors.blue.shade100
                                            : Colors.green.shade100,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        targetUser.isDriver
                                            ? "Driver"
                                            : "Penumpang",
                                        style: TextStyle(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.bold,
                                          color: targetUser.isDriver
                                              ? Colors.blue.shade900
                                              : Colors.green.shade900,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 6),
                                    _buildUnreadBadge(conv.id),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  targetUser.subtitle,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          IconButton(
                            tooltip: "Hapus Chat",
                            icon: const Icon(
                              Icons.delete_outline,
                              color: Colors.red,
                              size: 20,
                            ),
                            onPressed: () =>
                                _confirmDeleteCsConversation(targetUser),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Cuplikan Pesan Terakhir
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF7F8FA),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.chat_bubble_outline,
                              size: 14,
                              color: Colors.grey[600],
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                lastMsg,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[700],
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Divider(height: 20),

                      // Tombol Aksi
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.purple.shade700,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                elevation: 0,
                              ),
                              onPressed: () => _openChatRoom(targetUser),
                              icon: const Icon(Icons.reply, size: 16),
                              label: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Text(
                                    "Balas Chat",
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  if (unread > 0) ...[
                                    const SizedBox(width: 6),
                                    CircleAvatar(
                                      radius: 9,
                                      backgroundColor: Colors.red.shade600,
                                      child: Text(
                                        "$unread",
                                        style: const TextStyle(
                                          fontSize: 10,
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton.filledTonal(
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.green.shade50,
                              foregroundColor: Colors.green.shade800,
                            ),
                            tooltip: "Telepon Pengguna",
                            icon: const Icon(Icons.phone, size: 18),
                            onPressed: () => _startDirectCall(
                              targetUser: targetUser,
                              isVideo: false,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

        const SizedBox(height: 20),

        // 4. Bagian Inisiasi Chat Cepat (Hubungi Pengguna Shuttle)
        Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
          color: Colors.white,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.contact_support_outlined,
                      size: 20,
                      color: Colors.purple.shade700,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      "Mulai Chat Proaktif (Hubungi Pengguna)",
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  "Jika CS perlu menghubungi driver atau penumpang terlebih dahulu tanpa menunggu mereka chat:",
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _allUsers.where((u) => u.id != _currentUser.id).map(
                    (u) {
                      return ActionChip(
                        avatar: CircleAvatar(
                          radius: 10,
                          backgroundColor: u.isDriver
                              ? Colors.blue.shade100
                              : Colors.green.shade100,
                          child: Icon(
                            u.isDriver ? Icons.directions_bus : Icons.person,
                            size: 12,
                            color: u.isDriver
                                ? Colors.blue.shade900
                                : Colors.green.shade900,
                          ),
                        ),
                        label: Text(
                          u.name,
                          style: const TextStyle(fontSize: 12),
                        ),
                        onPressed: () => _openChatRoom(u),
                      );
                    },
                  ).toList(),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ==========================================================================
  // BOTTOMSHEET UNTUK GANTI AKUN TESTING (1 DRIVER, 2 PENUMPANG, 1 CS)
  // ==========================================================================
  void _showAccountSwitcherBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (bottomSheetContext) {
        return Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.75,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const Text(
                "Pilih Akun Demo Simulator",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const Text(
                "Ganti role akun untuk mendemokan alur Driver, Penumpang, atau CS.",
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView(
                  children: [
                    // GRUP 1: DRIVER (1 ORANG)
                    _buildRoleHeader("🚗 DRIVER SHUTTLE (1 AKUN)", Colors.blue),
                    ..._allUsers
                        .where((u) => u.isDriver)
                        .map((u) => _buildUserListTile(u, bottomSheetContext)),

                    const SizedBox(height: 16),

                    // GRUP 2: PENUMPANG (2 ORANG)
                    _buildRoleHeader(
                      "👤 PENUMPANG / CUSTOMER (2 AKUN)",
                      Colors.green,
                    ),
                    ..._allUsers
                        .where((u) => u.isCustomer)
                        .map((u) => _buildUserListTile(u, bottomSheetContext)),

                    const SizedBox(height: 16),

                    // GRUP 3: CUSTOMER SERVICE (1 ORANG)
                    _buildRoleHeader(
                      "🎧 CUSTOMER SERVICE (1 AKUN)",
                      Colors.purple,
                    ),
                    ..._allUsers
                        .where((u) => u.isCs)
                        .map((u) => _buildUserListTile(u, bottomSheetContext)),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRoleHeader(String title, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: color,
          letterSpacing: 0.5,
        ),
      ),
    );
  }

  Widget _buildUserListTile(ShuttleUser user, BuildContext sheetCtx) {
    final isCurrent = user.id == _currentUser.id;
    final hasToken = user.token.isNotEmpty;

    Color badgeColor;
    IconData icon;
    if (user.isDriver) {
      badgeColor = Colors.blue;
      icon = Icons.drive_eta;
    } else if (user.isCs) {
      badgeColor = Colors.purple;
      icon = Icons.support_agent;
    } else {
      badgeColor = Colors.green;
      icon = Icons.person;
    }

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isCurrent ? badgeColor : Colors.grey.shade200,
          width: isCurrent ? 2 : 1,
        ),
      ),
      color: isCurrent ? badgeColor.withOpacity(0.08) : Colors.white,
      child: ListTile(
        onTap: () {
          Navigator.pop(sheetCtx);
          _switchUser(user);
        },
        leading: CircleAvatar(
          backgroundColor: badgeColor.withOpacity(0.12),
          child: Icon(icon, color: badgeColor),
        ),
        title: Text(
          user.name,
          style: TextStyle(
            fontWeight: isCurrent ? FontWeight.bold : FontWeight.w600,
            fontSize: 14,
          ),
        ),
        subtitle: Text(
          "${user.subtitle}\nID: ${user.id}",
          style: const TextStyle(fontSize: 11),
        ),
        isThreeLine: true,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (!hasToken)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  "No Token",
                  style: TextStyle(color: Colors.red, fontSize: 10),
                ),
              ),
            const SizedBox(width: 8),
            if (isCurrent)
              Icon(Icons.check_circle, color: badgeColor)
            else
              const Icon(Icons.chevron_right, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  // ==========================================================================
  // DIALOG KELOLA TOKEN AGORA UNTUK SETIAP AKUN
  // ==========================================================================
  void _showTokenManagerDialog() {
    showDialog(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: const Row(
            children: [
              Icon(Icons.key, color: COLORS.primary),
              SizedBox(width: 8),
              Text("Kelola Token Agora", style: TextStyle(fontSize: 16)),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: _allUsers.length,
              separatorBuilder: (_, __) => const Divider(height: 12),
              itemBuilder: (context, i) {
                final u = _allUsers[i];
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    u.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                  subtitle: Text(
                    u.token.isEmpty
                        ? "⚠️ Token Kosong"
                        : "Token: ${u.token.substring(0, 15)}...",
                    style: TextStyle(
                      fontSize: 11,
                      color: u.token.isEmpty
                          ? Colors.red
                          : Colors.green.shade700,
                    ),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.edit, size: 18),
                    onPressed: () => _editTokenDialog(u),
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogCtx),
              child: const Text("Tutup"),
            ),
          ],
        );
      },
    );
  }

  void _editTokenDialog(ShuttleUser user) {
    final controller = TextEditingController(text: user.token);

    showDialog(
      context: context,
      builder: (editCtx) {
        return AlertDialog(
          title: Text(
            "Edit Token: ${user.name}",
            style: const TextStyle(fontSize: 15),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Paste Chat User Token dari Agora Console:",
                style: TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: controller,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: "007eJxTY...",
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(editCtx),
              child: const Text("Batal"),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  user.token = controller.text.trim();
                  if (user.id == _currentUser.id) {
                    _loginAgora();
                  }
                });
                Navigator.pop(editCtx);
              },
              child: const Text("Simpan"),
            ),
          ],
        );
      },
    );
  }
}
