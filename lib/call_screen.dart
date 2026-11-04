import 'dart:async';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'main.dart'; // Untuk AgoraConfig

class CallScreen extends StatefulWidget {
  final String channelId;
  final bool isVideoCall;
  final String targetName;

  const CallScreen({
    super.key,
    required this.channelId,
    required this.isVideoCall,
    required this.targetName,
  });

  @override
  State<CallScreen> createState() => _CallScreenState();
}

class _CallScreenState extends State<CallScreen> {
  RtcEngine? _engine;
  int? _remoteUid;
  bool _localUserJoined = false;
  bool _isMuted = false;
  bool _isVideoDisabled = false;
  bool _isSpeaker = true;

  int _callDuration = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _initAgoraRtc();
  }

  Future<void> _initAgoraRtc() async {
    debugPrint("=================================================");
    debugPrint("[AGORA RTC] 🚀 Inisialisasi Layar Panggilan (CallScreen)...");
    debugPrint("[AGORA RTC] Target Lawan Bicara : ${widget.targetName}");
    debugPrint("[AGORA RTC] Channel ID          : ${widget.channelId}");
    debugPrint(
      "[AGORA RTC] Tipe Panggilan      : ${widget.isVideoCall ? 'VIDEO CALL' : 'VOICE CALL'}",
    );
    debugPrint("[AGORA RTC] AppID RTC           : ${AgoraConfig.rtcAppId}");

    // 1. Minta izin akses mikrofon & kamera
    debugPrint("[AGORA RTC] 🔐 Memeriksa izin perangkat...");
    if (widget.isVideoCall) {
      final statuses = await [
        Permission.microphone,
        Permission.camera,
      ].request();

      if (statuses[Permission.microphone] != PermissionStatus.granted ||
          statuses[Permission.camera] != PermissionStatus.granted) {
        debugPrint("[AGORA RTC] ❌ Izin Kamera/Mikrofon ditolak!");
        _showErrorAndExit(
          "Izin kamera dan mikrofon diperlukan untuk video call.",
        );
        return;
      }
    } else {
      final status = await Permission.microphone.request();
      if (status != PermissionStatus.granted) {
        debugPrint("[AGORA RTC] ❌ Izin Mikrofon ditolak!");
        _showErrorAndExit("Izin mikrofon diperlukan untuk panggilan suara.");
        return;
      }
    }
    debugPrint("[AGORA RTC] ✅ Izin perangkat diberikan!");

    try {
      // 2. Buat dan inisialisasi RTC Engine
      debugPrint("[AGORA RTC] Membuat RtcEngine...");
      _engine = createAgoraRtcEngine();
      await _engine!.initialize(
        const RtcEngineContext(
          appId: AgoraConfig.rtcAppId,
          channelProfile: ChannelProfileType.channelProfileCommunication,
        ),
      );
      debugPrint("[AGORA RTC] ✅ RtcEngine berhasil diinisialisasi.");

      // 3. Daftarkan Event Handler untuk pantau status panggilan
      _engine!.registerEventHandler(
        RtcEngineEventHandler(
          onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
            debugPrint("=================================================");
            debugPrint(
              "[AGORA RTC] 🎉 onJoinChannelSuccess: Berhasil gabung channel!",
            );
            debugPrint("[AGORA RTC] ChannelId : ${connection.channelId}");
            debugPrint("[AGORA RTC] Local Uid : ${connection.localUid}");
            debugPrint("=================================================");
            setState(() {
              _localUserJoined = true;
            });
            // Atur speakerphone setelah channel berhasil terhubung
            try {
              _engine?.setEnableSpeakerphone(_isSpeaker);
            } catch (e) {
              debugPrint("[AGORA RTC] setEnableSpeakerphone notice: $e");
            }
          },
          onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
            debugPrint("=================================================");
            debugPrint(
              "[AGORA RTC] 👤 onUserJoined: Lawan bicara ($remoteUid) bergabung ke channel ${connection.channelId}!",
            );
            debugPrint("[AGORA RTC] Panggilan tersambung secara dua arah!");
            debugPrint("=================================================");
            setState(() {
              _remoteUid = remoteUid;
            });
            _startCallTimer();
          },
          onUserOffline:
              (
                RtcConnection connection,
                int remoteUid,
                UserOfflineReasonType reason,
              ) {
                debugPrint(
                  "[AGORA RTC] 📴 onUserOffline: Lawan bicara ($remoteUid) keluar karena $reason.",
                );
                setState(() {
                  _remoteUid = null;
                });
                _showExitDialog("Lawan bicara telah mengakhiri panggilan.");
              },
          onConnectionStateChanged:
              (
                RtcConnection connection,
                ConnectionStateType state,
                ConnectionChangedReasonType reason,
              ) {
                debugPrint("=================================================");
                debugPrint(
                  "[AGORA RTC] 🌐 Status Koneksi: $state | Alasan: $reason",
                );
                debugPrint("=================================================");

                if (reason ==
                    ConnectionChangedReasonType.connectionChangedInvalidToken) {
                  debugPrint(
                    "[AGORA RTC] ❌ ERROR: Token RTC yang dimasukkan TIDAK VALID!",
                  );
                  _showErrorAndExit(
                    "Token RTC tidak valid! Pastikan menggunakan token RTC, bukan token Chat.",
                  );
                } else if (reason ==
                    ConnectionChangedReasonType.connectionChangedTokenExpired) {
                  debugPrint("[AGORA RTC] ❌ ERROR: Token RTC KEDALUWARSA!");
                  _showErrorAndExit(
                    "Token RTC sudah kedaluwarsa. Silakan generate token baru.",
                  );
                } else if (reason ==
                    ConnectionChangedReasonType
                        .connectionChangedRejectedByServer) {
                  debugPrint(
                    "[AGORA RTC] ❌ ERROR: Ditolak oleh server Agora (mungkin App ID / App Certificate tidak cocok).",
                  );
                  _showErrorAndExit("Koneksi ditolak oleh server Agora.");
                }
              },
          onTokenPrivilegeWillExpire: (RtcConnection connection, String token) {
            debugPrint("[AGORA RTC] ⚠️ Token RTC akan kedaluwarsa!");
          },
          onError: (ErrorCodeType err, String msg) {
            debugPrint("[AGORA RTC] ❌ onError ($err): $msg");
          },
        ),
      );

      // 4. Konfigurasi Video / Audio
      if (widget.isVideoCall) {
        debugPrint("[AGORA RTC] Mengaktifkan mode Video...");
        await _engine!.enableVideo();
        await _engine!.startPreview();
      } else {
        debugPrint("[AGORA RTC] Mengaktifkan mode Audio murni...");
        await _engine!.enableAudio();
      }

      // Gunakan setDefaultAudioRouteToSpeakerphone sebelum joinChannel agar tidak melempar error -3 (ERR_NOT_READY)
      try {
        await _engine!.setDefaultAudioRouteToSpeakerphone(_isSpeaker);
      } catch (e) {
        debugPrint("[AGORA RTC] Notice setDefaultAudioRoute: $e");
      }

      // 5. Masuk ke Channel (Nama channel sama antara Driver dan Customer)
      final rtcToken = AgoraConfig.rtcToken;
      debugPrint(
        "[AGORA RTC] Menghubungi server Agora untuk join channel '${widget.channelId}'...",
      );
      debugPrint(
        "[AGORA RTC] Token yang digunakan: ${rtcToken.isEmpty ? '(Kosong / Testing Mode)' : '${rtcToken.substring(0, 15)}...'}",
      );

      await _engine!.joinChannel(
        token: rtcToken,
        channelId: widget.channelId,
        uid: 0,
        options: ChannelMediaOptions(
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
          channelProfile: ChannelProfileType.channelProfileCommunication,
          publishCameraTrack: widget.isVideoCall,
          publishMicrophoneTrack: true,
        ),
      );
      debugPrint("[AGORA RTC] joinChannel request selesai dikirim.");
    } catch (e) {
      debugPrint("[AGORA RTC] ❌ Exception saat _initAgoraRtc: $e");
      _showErrorAndExit("Gagal memulai panggilan: $e");
    }
  }

  void _startCallTimer() {
    _timer?.cancel();
    _callDuration = 0;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        _callDuration++;
      });
    });
  }

  String _formatDuration(int seconds) {
    final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
    final secs = (seconds % 60).toString().padLeft(2, '0');
    return "$minutes:$secs";
  }

  void _showErrorAndExit(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
    Navigator.of(context).pop();
  }

  void _showExitDialog(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
    _endCall();
  }

  // Kontrol Panggilan
  Future<void> _toggleMute() async {
    setState(() => _isMuted = !_isMuted);
    try {
      await _engine?.muteLocalAudioStream(_isMuted);
    } catch (e) {
      debugPrint("[AGORA RTC] Gagal mute audio: $e");
    }
  }

  Future<void> _toggleSpeaker() async {
    setState(() => _isSpeaker = !_isSpeaker);
    try {
      await _engine?.setEnableSpeakerphone(_isSpeaker);
    } catch (e) {
      debugPrint("[AGORA RTC] Gagal ganti speaker: $e");
    }
  }

  Future<void> _toggleVideo() async {
    setState(() => _isVideoDisabled = !_isVideoDisabled);
    await _engine?.muteLocalVideoStream(_isVideoDisabled);
  }

  Future<void> _switchCamera() async {
    await _engine?.switchCamera();
  }

  Future<void> _endCall() async {
    _timer?.cancel();
    try {
      await _engine?.leaveChannel();
      await _engine?.release();
    } catch (e) {
      debugPrint("Error saat release RTC: $e");
    }
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _engine?.leaveChannel();
    _engine?.release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E1E2C),
      body: SafeArea(
        child: widget.isVideoCall ? _buildVideoCallUI() : _buildVoiceCallUI(),
      ),
    );
  }

  // ==========================================================================
  // TAMPILAN VIDEO CALL
  // ==========================================================================
  Widget _buildVideoCallUI() {
    return Stack(
      children: [
        // Layar Utama: Video Lawan Bicara (Remote)
        Center(
          child: _remoteUid != null && _engine != null
              ? AgoraVideoView(
                  controller: VideoViewController.remote(
                    rtcEngine: _engine!,
                    canvas: VideoCanvas(uid: _remoteUid!),
                    connection: RtcConnection(channelId: widget.channelId),
                  ),
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundColor: Colors.white24,
                      child: const Icon(
                        Icons.person,
                        size: 60,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      widget.targetName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      "Menghubungkan video call...",
                      style: TextStyle(color: Colors.white70, fontSize: 14),
                    ),
                  ],
                ),
        ),

        // Floating View: Kamera Lokal (Kamera Kita Sendiri)
        if (_localUserJoined && _engine != null && !_isVideoDisabled)
          Positioned(
            top: 20,
            right: 20,
            width: 110,
            height: 150,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                color: Colors.black54,
                child: AgoraVideoView(
                  controller: VideoViewController(
                    rtcEngine: _engine!,
                    canvas: const VideoCanvas(uid: 0),
                  ),
                ),
              ),
            ),
          ),

        // Header Info (Nama & Durasi)
        Positioned(
          top: 20,
          left: 20,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black45,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.targetName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                Text(
                  _remoteUid != null
                      ? _formatDuration(_callDuration)
                      : "Menghubungkan...",
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ],
            ),
          ),
        ),

        // Kontrol Tombol di Bawah
        Positioned(
          bottom: 30,
          left: 0,
          right: 0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildActionButton(
                icon: _isMuted ? Icons.mic_off : Icons.mic,
                label: _isMuted ? "Unmute" : "Mute",
                isActive: _isMuted,
                onPressed: _toggleMute,
              ),
              _buildActionButton(
                icon: Icons.switch_camera,
                label: "Kamera",
                onPressed: _switchCamera,
              ),
              _buildActionButton(
                icon: _isVideoDisabled ? Icons.videocam_off : Icons.videocam,
                label: _isVideoDisabled ? "Nyalakan" : "Matikan",
                isActive: _isVideoDisabled,
                onPressed: _toggleVideo,
              ),
              _buildActionButton(
                icon: Icons.call_end,
                label: "Akhiri",
                backgroundColor: Colors.red,
                iconColor: Colors.white,
                onPressed: _endCall,
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ==========================================================================
  // TAMPILAN VOICE CALL
  // ==========================================================================
  Widget _buildVoiceCallUI() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.only(top: 30),
          child: Text(
            "Panggilan Suara",
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 16,
            ),
          ),
        ),

        // Profil Tengah
        Column(
          children: [
            CircleAvatar(
              radius: 65,
              backgroundColor: Colors.green.shade700,
              child: const Icon(Icons.person, size: 80, color: Colors.white),
            ),
            const SizedBox(height: 20),
            Text(
              widget.targetName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 26,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              _remoteUid != null
                  ? _formatDuration(_callDuration)
                  : "Menghubungkan ke ${widget.targetName}...",
              style: const TextStyle(color: Colors.white70, fontSize: 16),
            ),
          ],
        ),

        // Kontrol Tombol Bawah
        Padding(
          padding: const EdgeInsets.only(bottom: 40),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildActionButton(
                icon: _isMuted ? Icons.mic_off : Icons.mic,
                label: _isMuted ? "Unmute" : "Mute",
                isActive: _isMuted,
                onPressed: _toggleMute,
              ),
              _buildActionButton(
                icon: _isSpeaker ? Icons.volume_up : Icons.volume_off,
                label: "Speaker",
                isActive: _isSpeaker,
                onPressed: _toggleSpeaker,
              ),
              _buildActionButton(
                icon: Icons.call_end,
                label: "Akhiri",
                backgroundColor: Colors.red,
                iconColor: Colors.white,
                onPressed: _endCall,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    Color? backgroundColor,
    Color? iconColor,
    bool isActive = false,
  }) {
    final bgColor =
        backgroundColor ?? (isActive ? Colors.white : Colors.white24);
    final iColor = iconColor ?? (isActive ? Colors.black87 : Colors.white);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: onPressed,
          customBorder: const CircleBorder(),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: bgColor, shape: BoxShape.circle),
            child: Icon(icon, color: iColor, size: 28),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(color: Colors.white70, fontSize: 12),
        ),
      ],
    );
  }
}
