import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/di/injection.dart';
import '../../../core/widgets/neumorphic_container.dart';
import '../bloc/walkie_talkie_bloc.dart';
import '../bloc/walkie_talkie_event_state.dart';
import 'package:flutter/services.dart';

class WalkieTalkieScreen extends StatefulWidget {
  const WalkieTalkieScreen({super.key});

  @override
  State<WalkieTalkieScreen> createState() => _WalkieTalkieScreenState();
}

class _WalkieTalkieScreenState extends State<WalkieTalkieScreen> {
  late final WalkieTalkieBloc _bloc;
  DateTime? _lastPressedAt;

  void _showJoinDialog(BuildContext context) {
    final textController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('JOIN CHANNEL'),
        content: TextField(
          controller: textController,
          decoration: const InputDecoration(
            hintText: 'Enter Invite Link or Code',
            border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
          ),
        ),
        actions: [
          TextButton(onPressed: () => context.pop(), child: const Text('CANCEL')),
          ElevatedButton(
            onPressed: () {
              final code = textController.text.trim();
              if (code.isNotEmpty) {
                String groupId = code;
                if (code.contains('=')) groupId = code.split('=').last;
                _bloc.add(WalkieGroupJoinedByInvite(groupId));
                context.pop();
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Theme.of(context).primaryColor),
            child: const Text('JOIN'),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _bloc = getIt<WalkieTalkieBloc>()..add(WalkieInitialized());
  }

  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return BlocProvider.value(
      value: _bloc,
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) {
          if (didPop) return;
          final now = DateTime.now();
          if (_lastPressedAt == null || now.difference(_lastPressedAt!) > const Duration(seconds: 2)) {
            _lastPressedAt = now;
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Press back again to exit'), duration: Duration(seconds: 2)),
            );
          } else {
            SystemNavigator.pop();
          }
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
                    const NeumorphicContainer(
                      width: 50,
                      height: 50,
                      shape: BoxShape.circle,
                      child: Icon(Icons.mic_none_outlined),
                    ),
                    Text(
                      'VIBECAST',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(letterSpacing: 2.0),
                    ),
                    GestureDetector(
                      onTap: () {
                        showModalBottomSheet(
                          context: context,
                          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
                          builder: (context) => Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('OPTIONS', style: Theme.of(context).textTheme.titleLarge?.copyWith(letterSpacing: 2)),
                                const SizedBox(height: 24),
                                GestureDetector(
                                  onTap: () {
                                    context.pop();
                                    context.push('/walkie-talkie/create-group');
                                  },
                                  child: NeumorphicContainer(
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    borderRadius: 16,
                                    child: const Center(child: Text('CREATE NEW CHANNEL', style: TextStyle(fontWeight: FontWeight.bold))),
                                  ),
                                ),
                                const SizedBox(height: 16),
                                GestureDetector(
                                  onTap: () {
                                    context.pop();
                                    _showJoinDialog(context);
                                  },
                                  child: NeumorphicContainer(
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    borderRadius: 16,
                                    child: const Center(child: Text('JOIN VIA INVITE LINK', style: TextStyle(fontWeight: FontWeight.bold))),
                                  ),
                                ),
                                const SizedBox(height: 16),
                              ],
                            ),
                          ),
                        );
                      },
                      child: const NeumorphicContainer(
                        width: 50,
                        height: 50,
                        shape: BoxShape.circle,
                        child: Icon(Icons.add),
                      ),
                    ),
                  ],
                ),
              ),
              
              // Codec Setting
              BlocBuilder<WalkieTalkieBloc, WalkieTalkieState>(
                builder: (context, state) {
                  if (state is WalkieTalkieGroupsLoaded) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
                      child: NeumorphicContainer(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        borderRadius: 16,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text('Codec Mode', style: Theme.of(context).textTheme.bodyLarge),
                            Row(
                              children: [
                                Text(state.useOpus ? 'Opus' : 'PCM', style: const TextStyle(fontWeight: FontWeight.bold)),
                                const SizedBox(width: 8),
                                Switch(
                                  value: state.useOpus,
                                  onChanged: (val) => _bloc.add(WalkieCodecToggled(val)),
                                  activeTrackColor: Theme.of(context).primaryColor,
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
              
              Expanded(
                child: BlocBuilder<WalkieTalkieBloc, WalkieTalkieState>(
                  builder: (context, state) {
                    if (state is WalkieTalkieLoading || state is WalkieTalkieInitial) {
                      return Center(child: CircularProgressIndicator(color: Theme.of(context).primaryColor));
                    } else if (state is WalkieTalkieFailure) {
                      return Center(child: Text(state.message, style: const TextStyle(color: Colors.red)));
                    } else if (state is WalkieTalkieGroupsLoaded) {
                      if (state.groups.isEmpty) {
                        return Center(
                          child: Text(
                            'No channels yet.\nCreate one or join via invite.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: isDark ? Colors.grey[500] : Colors.grey[400]),
                          ),
                        );
                      }
                      return ListView.separated(
                        padding: const EdgeInsets.all(24),
                        itemCount: state.groups.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 16),
                        itemBuilder: (context, index) {
                          final group = state.groups[index];
                          return GestureDetector(
                            onTap: () => context.push('/walkie-talkie/channel', extra: group),
                            child: NeumorphicContainer(
                              padding: const EdgeInsets.all(16),
                              borderRadius: 20,
                              child: Row(
                                children: [
                                  NeumorphicContainer(
                                    width: 50,
                                    height: 50,
                                    shape: BoxShape.circle,
                                    child: Icon(Icons.hub_rounded, color: Theme.of(context).primaryColor),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(group.name, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 18)),
                                        Text('${group.memberCount} members', style: Theme.of(context).textTheme.bodyMedium),
                                      ],
                                    ),
                                  ),
                                  const Icon(Icons.chevron_right, color: Colors.grey),
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
            ],
          ),
        ),
      ),
      ),
    );
  }
}
