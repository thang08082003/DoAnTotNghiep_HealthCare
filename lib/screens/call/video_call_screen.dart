import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import '../../providers/user_provider.dart';
import '../../data/config/agora_config.dart';

class VideoCallScreen extends ConsumerStatefulWidget {
  final String
  channelName; // Use a deterministic channel name per doctor-patient pair
  const VideoCallScreen({super.key, required this.channelName});

  @override
  ConsumerState<VideoCallScreen> createState() => _VideoCallScreenState();
}

class _VideoCallScreenState extends ConsumerState<VideoCallScreen> {
  RtcEngine? _engine;
  int? _remoteUid;
  String? _error;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      // Request permissions (only on mobile platforms)
      if (Platform.isAndroid || Platform.isIOS) {
        await [Permission.camera, Permission.microphone].request();
      }

      final currentUser = await ref.read(currentUserProvider.future);
      if (currentUser == null) {
        setState(() => _error = 'Bạn cần đăng nhập để thực hiện cuộc gọi');
        return;
      }
      // Use a numeric uid for Agora (hash of user id)
      final uid = currentUser.uid.hashCode & 0x7fffffff;

      // Validate App ID
      if (agoraAppId.isEmpty || agoraAppId == 'YOUR_AGORA_APP_ID') {
        setState(
          () => _error =
              'Thiếu Agora App ID. Hãy mở lib/data/config/agora_config.dart và đặt giá trị chính xác cho agoraAppId.',
        );
        return;
      }

      final token = await _fetchToken(widget.channelName, uid);
      if (token == null) {
        setState(() => _error = 'Không lấy được token');
        return;
      }

      final engine = createAgoraRtcEngine();
      await engine.initialize(
        RtcEngineContext(appId: agoraAppId),
      ); // App ID not required when using token from your server if set server-side, but best practice is to set your Agora App ID here.

      engine.registerEventHandler(
        RtcEngineEventHandler(
          onJoinChannelSuccess: (RtcConnection connection, int elapsed) {},
          onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
            setState(() => _remoteUid = remoteUid);
          },
          onUserOffline:
              (
                RtcConnection connection,
                int remoteUid,
                UserOfflineReasonType reason,
              ) {
                setState(() => _remoteUid = null);
              },
          onError: (ErrorCodeType err, String msg) {
            setState(() => _error = 'Agora error: $err $msg');
          },
        ),
      );

      await engine.enableVideo();
      await engine.startPreview();

      await engine.joinChannel(
        token: token,
        channelId: widget.channelName,
        uid: uid,
        options: const ChannelMediaOptions(
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
          channelProfile: ChannelProfileType.channelProfileCommunication,
        ),
      );

      setState(() => _engine = engine);
    } catch (e) {
      setState(() => _error = 'Khởi tạo cuộc gọi thất bại: $e');
    }
  }

  Future<String?> _fetchToken(String channel, int uid) async {
    final url = Uri.parse(
      'https://agora-token-server-3fe8an8ao-thang08082003s-projects.vercel.app/access_token?channelName=$channel&uid=$uid&role=publisher&expireTime=3600',
    );
    final res = await http.get(url);
    if (res.statusCode == 200) {
      // Expecting {"token":"..."}
      try {
        final json = jsonDecode(res.body) as Map<String, dynamic>;
        return json['token'] as String? ??
            res.body; // fallback if server returns plain token
      } catch (_) {
        return res.body; // assume plain token string
      }
    }
    return null;
  }

  @override
  void dispose() {
    _engine?.leaveChannel();
    _engine?.release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cuộc gọi video')),
      body: _error != null
          ? Center(child: Text(_error!))
          : Column(
              children: [
                Expanded(
                  child: Stack(
                    children: [
                      // Remote view
                      if (_remoteUid != null)
                        AgoraVideoView(
                          controller: VideoViewController.remote(
                            rtcEngine: _engine!,
                            canvas: VideoCanvas(uid: _remoteUid),
                            connection: RtcConnection(
                              channelId: widget.channelName,
                            ),
                          ),
                        )
                      else
                        const Center(
                          child: Text('Đang chờ đối phương tham gia…'),
                        ),

                      // Local preview (small)
                      Positioned(
                        right: 16,
                        bottom: 16,
                        width: 120,
                        height: 180,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            color: Colors.black26,
                          ),
                          child: _engine == null
                              ? const SizedBox.shrink()
                              : AgoraVideoView(
                                  controller: VideoViewController(
                                    rtcEngine: _engine!,
                                    canvas: const VideoCanvas(uid: 0),
                                  ),
                                ),
                        ),
                      ),
                    ],
                  ),
                ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.switch_camera),
                          onPressed: () => _engine?.switchCamera(),
                        ),
                        IconButton(
                          icon: const Icon(Icons.mic_off),
                          onPressed: () async {
                            // Toggle microphone
                            // For brevity, simple mute toggle
                            // You can manage state if needed
                            await _engine?.muteLocalAudioStream(true);
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.call_end, color: Colors.red),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
