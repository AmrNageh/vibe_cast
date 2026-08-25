import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../../../core/di/injection.dart';
import '../../../core/widgets/neumorphic_container.dart';
import '../bloc/walkie_talkie_bloc.dart';
import '../bloc/walkie_talkie_event_state.dart';
import '../models/walkie_group_entity.dart';
import '../services/audio_capture_service.dart';
import '../services/audio_playback_service.dart';
import '../services/walkie_repository.dart';
import '../services/walkie_signal_service.dart';
class WalkieChannelScreen extends StatefulWidget {
  final WalkieGroupEntity group;
  const WalkieChannelScreen({super.key, required this.group});

  @override
  State<WalkieChannelScreen> createState() => _WalkieChannelScreenState();
}

class _WalkieChannelScreenState extends State<WalkieChannelScreen> with SingleTickerProviderStateMixin {
  late final WalkieTalkieBloc _bloc;
  late final AnimationController _waveController;
  String? _selectedTargetUserId;
  String _currentStatus = 'Active';

  void _showChatSheet(BuildContext context, WalkieTalkieInChannel state) {
    final textController = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.6,
            child: Column(
              children: [
                const SizedBox(height: 16),
                Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey, borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 16),
                Text('CHANNEL CHAT', style: Theme.of(context).textTheme.titleMedium?.copyWith(letterSpacing: 2)),
                const Divider(),
                Expanded(
                  child: BlocBuilder<WalkieTalkieBloc, WalkieTalkieState>(
                    bloc: _bloc,
                    builder: (context, blocState) {
                      if (blocState is WalkieTalkieInChannel) {
                        return ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: blocState.chatHistory.length,
                          itemBuilder: (context, index) {
                            final msg = blocState.chatHistory[index];
                            final isMe = msg.senderId == getIt<WalkieRepository>().userId;
                            return Align(
                              alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isMe ? Theme.of(context).primaryColor : Colors.grey[800],
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (!isMe) Text(msg.senderName, style: const TextStyle(fontSize: 10, color: Colors.white70)),
                                    Text(msg.text, style: const TextStyle(color: Colors.white)),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      }
                      return const SizedBox();
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: textController,
                          decoration: InputDecoration(
                            hintText: 'Type a message...',
                            filled: true,
                            fillColor: Theme.of(context).brightness == Brightness.dark ? Colors.grey[900] : Colors.grey[200],
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                            contentPadding: const EdgeInsets.symmetric(horizontal: 20),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      GestureDetector(
                        onTap: () {
                          if (textController.text.trim().isNotEmpty) {
                            getIt<WalkieSignalService>().sendChatMessage(
                              state.group.id,
                              getIt<WalkieRepository>().userName,
                              getIt<WalkieRepository>().userId,
                              textController.text.trim(),
                            );
                            textController.clear();
                          }
                        },
                        child: CircleAvatar(
                          backgroundColor: Theme.of(context).primaryColor,
                          child: const Icon(Icons.send, color: Colors.white, size: 20),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    _bloc = getIt<WalkieTalkieBloc>()..add(WalkieChannelEntered(widget.group));
    _waveController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000))..repeat(reverse: true);
    _waveController.addListener(() {
      if (mounted) setState(() {});
    });
    
    // Hardware Button Listener for Volume Keys
    HardwareKeyboard.instance.addHandler(_handleVolumeKey);
  }

  bool _handleVolumeKey(KeyEvent event) {
    if (event.logicalKey == LogicalKeyboardKey.audioVolumeDown || event.logicalKey == LogicalKeyboardKey.audioVolumeUp) {
      if (event is KeyDownEvent) {
        _bloc.add(WalkiePTTPressed(targetUserId: _selectedTargetUserId));
      } else if (event is KeyUpEvent) {
        _bloc.add(WalkiePTTReleased());
      }
      return true; // handled
    }
    return false;
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    HardwareKeyboard.instance.removeHandler(_handleVolumeKey);
    _waveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _bloc,
      child: BlocListener<WalkieTalkieBloc, WalkieTalkieState>(
        listener: (context, state) {
          if (state is WalkieTalkieInChannel) {
            if (state.status == TransmissionStatus.transmitting) {
              HapticFeedback.heavyImpact();
            } else if (state.status == TransmissionStatus.idle) {
              HapticFeedback.heavyImpact();
            } else if (state.status == TransmissionStatus.receiving) {
              HapticFeedback.heavyImpact();
            }
          }
        },
        child: PopScope(
          canPop: true,
          onPopInvokedWithResult: (didPop, _) {
            _bloc.add(WalkieGroupLeft(widget.group.id));
          },
          child: Scaffold(
            body: SafeArea(
              child: Column(
                children: [
                // Top Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      GestureDetector(
                        onTap: () {
                          _bloc.add(WalkieGroupLeft(widget.group.id));
                          context.pop();
                        },
                        child: const NeumorphicContainer(
                          width: 50,
                          height: 50,
                          shape: BoxShape.circle,
                          child: Icon(Icons.arrow_back),
                        ),
                      ),
                      Row(
                        children: [
                          GestureDetector(
                            onTap: () {
                              Clipboard.setData(ClipboardData(text: widget.group.id));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Invite Code Copied!')),
                              );
                            },
                            child: const NeumorphicContainer(
                              width: 50,
                              height: 50,
                              shape: BoxShape.circle,
                              child: Icon(Icons.copy, size: 20),
                            ),
                          ),
                          const SizedBox(width: 16),
                          BlocBuilder<WalkieTalkieBloc, WalkieTalkieState>(
                            builder: (context, state) {
                              return GestureDetector(
                                onTap: () {
                                  HapticFeedback.heavyImpact();
                                  if (state is WalkieTalkieInChannel) {
                                    _showChatSheet(context, state);
                                  }
                                },
                                child: const NeumorphicContainer(
                                  width: 50,
                                  height: 50,
                                  shape: BoxShape.circle,
                                  child: Icon(Icons.chat_bubble_rounded, size: 20),
                                ),
                              );
                            }
                          ),
                          const SizedBox(width: 16),
                          GestureDetector(
                            onTap: () {
                                showDialog(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('Leave Group'),
                                    content: const Text('Are you sure you want to permanently leave this group?'),
                                    actions: [
                                      TextButton(onPressed: () => context.pop(), child: const Text('CANCEL')),
                                      TextButton(
                                        onPressed: () {
                                          HapticFeedback.heavyImpact();
                                          _bloc.add(WalkieGroupPermanentlyLeft(widget.group.id));
                                          context.pop(); // Close dialog
                                          context.pop(); // Exit screen
                                        },
                                        child: const Text('LEAVE', style: TextStyle(color: Colors.red)),
                                      ),
                                    ],
                                  ),
                                );
                            },
                            child: const NeumorphicContainer(
                              width: 50,
                              height: 50,
                              shape: BoxShape.circle,
                              child: Icon(Icons.exit_to_app, size: 20, color: Colors.red),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),



              // Main PTT Area (mimicking the bottom sheet)
              Expanded(
                child: NeumorphicContainer(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  borderRadius: 40,
                  child: BlocBuilder<WalkieTalkieBloc, WalkieTalkieState>(
                    builder: (context, state) {
                      final isTransmitting = state is WalkieTalkieInChannel && state.status == TransmissionStatus.transmitting;
                      final isReceiving = state is WalkieTalkieInChannel && state.status == TransmissionStatus.receiving;
                      
                      return Stack(
                        alignment: Alignment.center,
                        children: [
                          Positioned(
                            top: 16,
                            child: Container(
                              width: 60,
                              height: 4,
                              decoration: BoxDecoration(
                                color: Colors.grey.withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                          
                          // Nokia LCD Screen ABOVE the PTT button
                          Positioned(
                            top: 10,
                            left: 32,
                            right: 32,
                            bottom: 350,
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF87A96B) : const Color(0xFFE5E5E5),
                                borderRadius: BorderRadius.circular(15),
                                border: Border.all(color: Colors.black45, width: 3),
                                boxShadow: [
                                  BoxShadow(
                                    color: (Theme.of(context).brightness == Brightness.dark ? Colors.greenAccent : Colors.black54).withValues(alpha: 0.2), 
                                    blurRadius: 10, 
                                    spreadRadius: 2,
                                  )
                                ],
                              ),
                              child: Column(
                                children: [
                                  Text(
                                    '${widget.group.name.toUpperCase()} MEMBERS',
                                    style: const TextStyle(fontFamily: 'DotGothic16', fontSize: 14, color: Colors.black54, fontWeight: FontWeight.bold),
                                  ),
                                  const Divider(color: Colors.black26, height: 8, thickness: 1),
                                  Expanded(
                                    child: (state is WalkieTalkieInChannel) ? ListView.builder(
                                      padding: EdgeInsets.zero,
                                      itemCount: state.members.length + 1,
                                      itemBuilder: (context, index) {
                                        if (index == 0) {
                                          final isTalkToAll = _selectedTargetUserId == null;
                                          return GestureDetector(
                                            onTap: () {
                                              HapticFeedback.selectionClick();
                                              setState(() => _selectedTargetUserId = null);
                                            },
                                            child: Container(
                                              margin: const EdgeInsets.only(bottom: 4),
                                              padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                                              decoration: BoxDecoration(
                                                color: isTalkToAll ? Colors.black26 : Colors.transparent,
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: Row(
                                                children: [
                                                  Icon(Icons.public, size: 20, color: isTalkToAll ? Colors.white : Colors.black87),
                                                  const SizedBox(width: 16),
                                                  Expanded(
                                                    child: Text(
                                                      'TALK TO ALL',
                                                      style: TextStyle(
                                                        fontFamily: 'DotGothic16', 
                                                        fontSize: 16, 
                                                        color: isTalkToAll ? Colors.white : Colors.black87, 
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          );
                                        }

                                        final member = state.members[index - 1];
                                        if (member.id == getIt<WalkieRepository>().userId) return const SizedBox.shrink();
                                        
                                        final isSelected = _selectedTargetUserId == member.id;
                                        return Container(
                                          margin: const EdgeInsets.only(bottom: 4),
                                          padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
                                          decoration: BoxDecoration(
                                            color: isSelected ? Colors.black26 : Colors.transparent,
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  member.name.toUpperCase(),
                                                  style: TextStyle(
                                                    fontFamily: 'DotGothic16', 
                                                    fontSize: 16, 
                                                    color: isSelected ? Colors.white : Colors.black87, 
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                              GestureDetector(
                                                onTap: () {
                                                  HapticFeedback.lightImpact();
                                                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('DM ${member.name} (Coming soon)')));
                                                },
                                                child: Icon(Icons.message, size: 20, color: isSelected ? Colors.white70 : Colors.black54),
                                              ),
                                              const SizedBox(width: 16),
                                              GestureDetector(
                                                onTap: () {
                                                  HapticFeedback.selectionClick();
                                                  setState(() => _selectedTargetUserId = member.id);
                                                },
                                                child: Icon(
                                                  Icons.settings_voice, 
                                                  size: 20, 
                                                  color: isSelected ? Colors.red[900] : Colors.black54,
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                    ) : const Center(
                                      child: Text(
                                        'CONNECTING...',
                                        textAlign: TextAlign.center,
                                        style: TextStyle(fontFamily: 'DotGothic16', fontSize: 16, color: Colors.black54),
                                      ),
                                    ),
                                  ),
                                  
                                  // Waveform INSIDE LCD Screen
                                  const SizedBox(height: 8),
                                  SizedBox(
                                    height: 40,
                                    child: StreamBuilder<double>(
                                      stream: isReceiving 
                                        ? getIt<AudioPlaybackService>().playbackAmplitudeStream 
                                        : getIt<AudioCaptureService>().amplitudeStream,
                                      initialData: 0.0,
                                      builder: (context, snapshot) {
                                        final amplitude = snapshot.data ?? 0.0;
                                        return Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          crossAxisAlignment: CrossAxisAlignment.center,
                                          children: List.generate(40, (index) {
                                            double activeHeight = 4.0;
                                            if (isTransmitting) {
                                              final localScale = (index % 5 + 1) / 5;
                                              activeHeight = 4.0 + (30 * amplitude * localScale);
                                            } else if (isReceiving) {
                                              final localScale = (index % 6 + 1) / 6;
                                              activeHeight = 4.0 + (15 * amplitude * localScale);
                                            }

                                            return AnimatedContainer(
                                              duration: const Duration(milliseconds: 50),
                                              margin: const EdgeInsets.symmetric(horizontal: 2),
                                              width: 3,
                                              height: activeHeight,
                                              decoration: BoxDecoration(
                                                color: isTransmitting || isReceiving 
                                                  ? Colors.black87 // Active "pixels"
                                                  : Colors.black26, // Idle "pixels"
                                                borderRadius: BorderRadius.circular(1),
                                              ),
                                            );
                                          }),
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          // Giant PTT Button anchored to center-bottom
                          Positioned(
                            bottom: 110,
                            child: GestureDetector(
                              onLongPressStart: (_) {
                                if (isReceiving) {
                                  HapticFeedback.vibrate();
                                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Channel is busy. Wait for your turn.', style: TextStyle(color: Colors.white)), backgroundColor: Colors.red));
                                } else {
                                  _bloc.add(WalkiePTTPressed(targetUserId: _selectedTargetUserId));
                                }
                              },
                              onLongPressEnd: (_) => _bloc.add(WalkiePTTReleased(targetUserId: _selectedTargetUserId)),
                              child: NeumorphicContainer(
                                width: 220,
                                height: 220,
                                shape: BoxShape.circle,
                                isPressed: isTransmitting || isReceiving,
                                child: Center(
                                  child: Icon(
                                    isTransmitting ? Icons.mic : (isReceiving ? Icons.speaker_phone : Icons.mic_none),
                                    size: 100,
                                    color: isTransmitting 
                                      ? Colors.red 
                                      : (isReceiving 
                                        ? Colors.orange 
                                        : (Theme.of(context).brightness == Brightness.dark ? Colors.grey[300] : Colors.grey[400])),
                                  ),
                                ),
                              ),
                            ),
                          ),


                          // Bottom Action Row
                          Positioned(
                            bottom: 24,
                            left: 32,
                            right: 32,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                GestureDetector(
                                  onTap: () {
                                    HapticFeedback.lightImpact();
                                    if (state is WalkieTalkieInChannel) {
                                      _showChatSheet(context, state);
                                    }
                                  },
                                  child: const NeumorphicContainer(
                                    width: 50,
                                    height: 50,
                                    borderRadius: 16,
                                    child: Icon(Icons.history),
                                  ),
                                ),
                                NeumorphicContainer(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                                  borderRadius: 20,
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<String>(
                                      value: _currentStatus,
                                      icon: const Icon(Icons.arrow_drop_down),
                                      dropdownColor: Theme.of(context).scaffoldBackgroundColor,
                                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold),
                                      onChanged: (String? newValue) {
                                        if (newValue != null) {
                                          setState(() => _currentStatus = newValue);
                                          HapticFeedback.selectionClick();
                                        }
                                      },
                                      items: [
                                        DropdownMenuItem(
                                          value: 'Active',
                                          child: Row(children: [const Icon(Icons.circle, color: Colors.green, size: 12), const SizedBox(width: 8), Text('Active', style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color))]),
                                        ),
                                        DropdownMenuItem(
                                          value: 'Busy',
                                          child: Row(children: [const Icon(Icons.circle, color: Colors.orange, size: 12), const SizedBox(width: 8), Text('Busy', style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color))]),
                                        ),
                                        DropdownMenuItem(
                                          value: 'Offline',
                                          child: Row(children: [const Icon(Icons.circle, color: Colors.grey, size: 12), const SizedBox(width: 8), Text('Offline', style: TextStyle(color: Theme.of(context).textTheme.bodyLarge?.color))]),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () {
                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ping: 12ms (Local UDP)')));
                                  },
                                  child: const NeumorphicContainer(
                                    width: 50,
                                    height: 50,
                                    borderRadius: 16,
                                    child: Icon(Icons.bar_chart, color: Colors.green),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
          ),
        ),
      ),
      ),
    );
  }
}
