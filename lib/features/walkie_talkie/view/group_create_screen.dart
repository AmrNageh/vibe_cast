import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/di/injection.dart';
import '../../../core/widgets/neumorphic_container.dart';
import '../bloc/walkie_talkie_bloc.dart';
import '../bloc/walkie_talkie_event_state.dart';

class GroupCreateScreen extends StatefulWidget {
  const GroupCreateScreen({super.key});

  @override
  State<GroupCreateScreen> createState() => _GroupCreateScreenState();
}

class _GroupCreateScreenState extends State<GroupCreateScreen> {
  final _nameController = TextEditingController();
  late final WalkieTalkieBloc _bloc;

  @override
  void initState() {
    super.initState();
    _bloc = getIt<WalkieTalkieBloc>();
  }

  void _createGroup() {
    final name = _nameController.text.trim();
    if (name.isNotEmpty) {
      _bloc.add(WalkieGroupCreated(name: name, memberIds: [], isPrivate: false));
      context.pop();
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _bloc,
      child: Scaffold(
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => context.pop(),
                      child: const NeumorphicContainer(
                        width: 50,
                        height: 50,
                        shape: BoxShape.circle,
                        child: Icon(Icons.arrow_back),
                      ),
                    ),
                    const SizedBox(width: 20),
                    Text(
                      'NEW CHANNEL',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  children: [
                    NeumorphicContainer(
                      borderRadius: 16,
                      child: TextField(
                        controller: _nameController,
                        decoration: InputDecoration(
                          hintText: 'Channel Name',
                          hintStyle: TextStyle(color: Theme.of(context).textTheme.bodyMedium?.color?.withValues(alpha: 0.5)),
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                        ),
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ),
                    const SizedBox(height: 40),
                    GestureDetector(
                      onTap: _createGroup,
                      child: NeumorphicContainer(
                        borderRadius: 16,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        color: Theme.of(context).primaryColor,
                        child: const Center(
                          child: Text(
                            'CREATE',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              letterSpacing: 2.0,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
