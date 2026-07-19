import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/di/injection.dart';
import '../../../core/widgets/neumorphic_container.dart';
import '../bloc/walkie_talkie_bloc.dart';
import '../bloc/walkie_talkie_event_state.dart';

class WalkieTalkieScreen extends StatefulWidget {
  const WalkieTalkieScreen({super.key});

  @override
  State<WalkieTalkieScreen> createState() => _WalkieTalkieScreenState();
}

class _WalkieTalkieScreenState extends State<WalkieTalkieScreen> {
  late final WalkieTalkieBloc _bloc;

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
                      onTap: () => context.go('/walkie-talkie/create-group'),
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
                      return DefaultTabController(
                        length: 2,
                        child: Column(
                          children: [
                            TabBar(
                              indicatorColor: Theme.of(context).primaryColor,
                              labelColor: Theme.of(context).primaryColor,
                              unselectedLabelColor: isDark ? Colors.grey[500] : Colors.grey[400],
                              tabs: const [
                                Tab(text: 'CHANNELS'),
                                Tab(text: 'USERS'),
                              ],
                            ),
                            Expanded(
                              child: TabBarView(
                                children: [
                                  ListView.separated(
                                    padding: const EdgeInsets.all(24),
                                    itemCount: state.groups.length,
                                    separatorBuilder: (context, index) => const SizedBox(height: 16),
                                    itemBuilder: (context, index) {
                                      final group = state.groups[index];
                                      return GestureDetector(
                                        onTap: () => context.go('/walkie-talkie/channel', extra: group),
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
                                  ),
                                  ListView.separated(
                                    padding: const EdgeInsets.all(24),
                                    itemCount: state.onlineUsers.length,
                                    separatorBuilder: (context, index) => const SizedBox(height: 16),
                                    itemBuilder: (context, index) {
                                      final user = state.onlineUsers[index];
                                      return GestureDetector(
                                        onTap: () {
                                          _bloc.add(WalkieGroupCreated(
                                            name: 'Private: ${user.name}',
                                            memberIds: [user.id],
                                            isPrivate: true,
                                          ));
                                          ScaffoldMessenger.of(context).showSnackBar(
                                            SnackBar(content: Text('Calling ${user.name}...')),
                                          );
                                        },
                                        child: NeumorphicContainer(
                                          padding: const EdgeInsets.all(16),
                                          borderRadius: 20,
                                          child: Row(
                                            children: [
                                              NeumorphicContainer(
                                                width: 50,
                                                height: 50,
                                                shape: BoxShape.circle,
                                                child: Icon(Icons.person, color: Theme.of(context).primaryColor),
                                              ),
                                              const SizedBox(width: 16),
                                              Expanded(
                                                child: Text(user.name, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: 18)),
                                              ),
                                              Container(
                                                width: 12,
                                                height: 12,
                                                decoration: const BoxDecoration(
                                                  shape: BoxShape.circle,
                                                  color: Colors.green,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
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
    );
  }
}
