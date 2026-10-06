import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_operations/flutter_operations.dart';

import '../shared/example_layout.dart';
import '../shared/models.dart';
import '../shared/services.dart';
import '../shared/user_operation_view.dart';

class BlocIntegrationExample extends StatefulWidget {
  const BlocIntegrationExample({super.key});

  @override
  State<BlocIntegrationExample> createState() => _BlocIntegrationExampleState();
}

class _BlocIntegrationExampleState extends State<BlocIntegrationExample> {
  int selected = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bloc Integration')),
      body: ExampleBody(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SizedBox(
                    width: 600,
                    child: SegmentedButton<int>(
                      segments: const [
                        ButtonSegment(value: 0, label: Text('Direct Cubit')),
                        ButtonSegment(
                          value: 1,
                          label: Text('AsyncOperation-backed'),
                        ),
                        ButtonSegment(value: 2, label: Text('Mixin-backed')),
                      ],
                      selected: {selected},
                      onSelectionChanged: (selection) {
                        setState(() => selected = selection.single);
                      },
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: switch (selected) {
                1 => BlocProvider(
                  create: (_) => _ComposedUserCubit(),
                  child: const _ComposedUserView(),
                ),
                2 => BlocProvider(
                  create: (_) => _MixinUserCubit(),
                  child: const _MixinUserView(),
                ),
                _ => BlocProvider(
                  create: (_) => _DirectUserCubit(),
                  child: const _DirectUserView(),
                ),
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _DirectUserView extends StatelessWidget {
  const _DirectUserView();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<_DirectUserCubit, OperationState<User>>(
      builder: (context, operation) {
        final cubit = context.read<_DirectUserCubit>();
        return UserOperationView(
          operation: operation,
          run: cubit.load,
          cancel: cubit.cancel,
        );
      },
    );
  }
}

class _ComposedUserView extends StatelessWidget {
  const _ComposedUserView();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<_ComposedUserCubit, OperationState<User>>(
      builder: (context, operation) {
        final cubit = context.read<_ComposedUserCubit>();
        return UserOperationView(
          operation: operation,
          run: cubit.load,
          cancel: cubit.cancel,
        );
      },
    );
  }
}

class _DirectUserCubit extends Cubit<OperationState<User>> {
  _DirectUserCubit() : super(IdleOperation());

  int generation = 0;

  Future<void> load() async {
    final currentGeneration = ++generation;
    emit(LoadingOperation(data: state.dataOrNull));
    try {
      final user = await MockApiService.fetchUser();
      if (isClosed || currentGeneration != generation) return;
      emit(SuccessOperation(data: user));
    } catch (error, stackTrace) {
      if (isClosed || currentGeneration != generation) return;
      emit(
        ErrorOperation(
          data: state.dataOrNull,
          message: error.toString(),
          error: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }

  void cancel() {
    generation++;
    emit(IdleOperation(data: state.dataOrNull));
  }
}

class _ComposedUserCubit extends Cubit<OperationState<User>> {
  _ComposedUserCubit() : super(IdleOperation()) {
    operation = AsyncOperation<User>(
      initialState: state,
      onChanged: (_, next) => emit(next),
    );
  }

  late final AsyncOperation<User> operation;

  Future<void> load() => operation.run(MockApiService.fetchUser);

  void cancel() => operation.cancel();

  @override
  Future<void> close() {
    operation.dispose();
    return super.close();
  }
}

class _MixinUserView extends StatelessWidget {
  const _MixinUserView();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<_MixinUserCubit, OperationState<User>>(
      builder: (context, operation) {
        final cubit = context.read<_MixinUserCubit>();
        return UserOperationView(
          operation: operation,
          run: cubit.load,
          cancel: cubit.cancel,
        );
      },
    );
  }
}

class _MixinUserCubit extends Cubit<OperationState<User>>
    with AsyncOperationMixin<User> {
  _MixinUserCubit() : super(IdleOperation());

  @override
  Future<User> fetch() => MockApiService.fetchUser();

  @override
  void operationChanged(previous, next) {
    emit(next);
  }

  @override
  Future<void> close() {
    disposeOperation();
    return super.close();
  }
}
