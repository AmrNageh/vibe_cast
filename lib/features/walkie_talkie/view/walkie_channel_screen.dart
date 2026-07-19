import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/di/injection.dart';
import '../../../core/widgets/neumorphic_container.dart';
import '../bloc/walkie_talkie_bloc.dart';
import '../bloc/walkie_talkie_event_state.dart';
import '../models/walkie_group_entity.dart';
import '../services/audio_capture_service.dart';
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
    _bloc = getIt<WalkieTalkieBloc>()..add(WalkieChannelEntered(widget.group));
    _waveController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1000))..repeat(reverse: true);
  }

  @override
  void dispose() {
    _waveController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _bloc,
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
                        ],
                      ),
                    ],
                  ),
                ),

              // Active Contact Card
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: GestureDetector(
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                        title: Text('CHANNEL MEMBERS (${widget.group.memberCount})'),
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: widget.group.permanentMembers.isEmpty 
                            ? [const Text('No registered members yet.')]
                            : widget.group.permanentMembers.map((m) => ListTile(
                                leading: const Icon(Icons.person),
                                title: Text(m), // We don't have their names easily accessible yet, so ID is shown, or backend can provide full objects.
                              )).toList(),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => context.pop(),
                            child: const Text('CLOSE'),
                          ),
                        ],
                      ),
                    );
                  },
                  child: NeumorphicContainer(
                    padding: const EdgeInsets.all(16),
                    borderRadius: 20,
                    child: Row(
                      children: [
                        const NeumorphicContainer(
                          width: 60,
                          height: 60,
                          shape: BoxShape.circle,
                          child: Icon(Icons.person, size: 30),
                        ),
                        const SizedBox(width: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.group.name,
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 18),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Tap to view members',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[400] : Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 40),

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
                          
                          // Giant PTT Button anchored to center-bottom
                          Positioned(
                            bottom: 160,
                            child: GestureDetector(
                              onLongPressStart: (_) => _bloc.add(WalkiePTTPressed()),
                              onLongPressEnd: (_) => _bloc.add(WalkiePTTReleased()),
                              child: NeumorphicContainer(
                                width: 220,
                                height: 220,
                                shape: BoxShape.circle,
                                isPressed: isTransmitting,
                                child: Center(
                                  child: Icon(
                                    Icons.mic,
                                    size: 100,
                                    color: isTransmitting ? Colors.red : (Theme.of(context).brightness == Brightness.dark ? Colors.grey[300] : Colors.grey[400]),
                                  ),
                                ),
                              ),
                            ),
                          ),

                          // Waveform below PTT
                          Positioned(
                            bottom: 100,
                            left: 0,
                            right: 0,
                            child: SizedBox(
                              height: 60,
                              child: StreamBuilder<double>(
                                stream: getIt<AudioCaptureService>().amplitudeStream,
                                initialData: 0.0,
                                builder: (context, snapshot) {
                                  final amplitude = snapshot.data ?? 0.0;
                                  return Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.center,
                                    children: List.generate(40, (index) {
                                      // Default animation baseline
                                      double activeHeight = 8.0;
                                      
                                      if (isTransmitting) {
                                        // Dynamic based on microphone
                                        final localScale = (index % 5 + 1) / 5; // create some wave variation
                                        activeHeight = 8.0 + (50 * amplitude * localScale);
                                      } else if (isReceiving) {
                                        // Keep standard animation for receiving for now
                                        activeHeight = 8.0 + (30 * (_waveController.value * ((index % 6) + 1) / 6));
                                      }

                                      return AnimatedContainer(
                                        duration: const Duration(milliseconds: 50),
                                        margin: const EdgeInsets.symmetric(horizontal: 2),
                                        width: 3,
                                        height: activeHeight,
                                        decoration: BoxDecoration(
                                          color: isTransmitting || isReceiving 
                                            ? Theme.of(context).primaryColor 
                                            : (Theme.of(context).brightness == Brightness.dark ? Colors.grey[700] : Colors.grey[400]),
                                          borderRadius: BorderRadius.circular(2),
                                        ),
                                      );
                                    }),
                                  );
                                },
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
                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('History log opened.')));
                                  },
                                  child: const NeumorphicContainer(
                                    width: 50,
                                    height: 50,
                                    borderRadius: 16,
                                    child: Icon(Icons.history),
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () {
                                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Status set to Active.')));
                                  },
                                  child: NeumorphicContainer(
                                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                    borderRadius: 20,
                                    child: Row(
                                      children: [
                                        const Icon(Icons.check_circle_outline, color: Colors.green, size: 20),
                                        const SizedBox(width: 8),
                                        Text('Active', style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: Colors.green, fontWeight: FontWeight.bold)),
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
    );
  }
}
