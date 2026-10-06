import 'package:flutter/material.dart';
import 'package:flutter_mobx/flutter_mobx.dart';
import 'package:flutter_operations/flutter_operations.dart';
import 'package:mobx/mobx.dart';

import '../shared/example_layout.dart';
import '../shared/models.dart';
import '../shared/services.dart';
import '../shared/user_operation_view.dart';

part 'mobx_integration_example.g.dart';

class MobxIntegrationExample extends StatefulWidget {
  const MobxIntegrationExample({super.key});

  @override
  State<MobxIntegrationExample> createState() => _MobxIntegrationExampleState();
}

class _MobxIntegrationExampleState extends State<MobxIntegrationExample> {
  late final _UserStore store;
  late final SingleOperationStore single;
  late final MultipleOperationsStore multiple;
  late final ExtendedOperationStore extended;
  late final ReactiveMixinStore reactive;
  late final OverriddenControllerStore overridden;
  late final InjectedOperationStore injected;
  int selected = 0;

  @override
  void initState() {
    super.initState();
    store = _UserStore();
    single = SingleOperationStore();
    multiple = MultipleOperationsStore();
    extended = ExtendedOperationStore();
    reactive = ReactiveMixinStore();
    overridden = OverriddenControllerStore();
    injected = InjectedOperationStore(_MobxAsyncOperation<User>());
  }

  @override
  void dispose() {
    store.dispose();
    single.dispose();
    multiple.dispose();
    extended.dispose();
    reactive.disposeOperation();
    overridden.disposeOperation();
    injected.disposeOperation();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('MobX Integration')),
      body: ExampleBody(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DropdownButton<int>(
                  value: selected,
                  items: const [
                    DropdownMenuItem(
                      value: 0,
                      child: Text('Atom (no codegen)'),
                    ),
                    DropdownMenuItem(value: 1, child: Text('Mixin + Atom')),
                    DropdownMenuItem(value: 3, child: Text('Extends + Store')),
                    DropdownMenuItem(value: 4, child: Text('Reactive mixin')),
                    DropdownMenuItem(
                      value: 5,
                      child: Text('Override controller'),
                    ),
                    DropdownMenuItem(
                      value: 6,
                      child: Text('Injected controller'),
                    ),
                    DropdownMenuItem(
                      value: 2,
                      child: Text('Codegen: operation fields'),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => selected = value);
                  },
                ),
              ),
            ),
            if (selected == 2)
              Observer(
                builder: (_) => Column(
                  children: [
                    Text(switch (multiple.productsState) {
                      IdleOperation() => 'Products idle',
                      LoadingOperation() => 'Loading products...',
                      ErrorOperation(:final message) =>
                        message ?? 'Products unavailable',
                      SuccessOperation(:final data) =>
                        '${data.length} products',
                    }),
                    Wrap(
                      children: [
                        TextButton(
                          onPressed: multiple.loadProducts,
                          child: const Text('Load products'),
                        ),
                        TextButton(
                          onPressed: multiple.products.cancel,
                          child: const Text('Cancel products'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            Expanded(
              child: Observer(
                builder: (_) => switch (selected) {
                  1 => UserOperationView(
                    operation: single.operation,
                    run: single.load,
                    cancel: single.cancel,
                  ),
                  2 => UserOperationView(
                    operation: multiple.userState,
                    run: multiple.loadUser,
                    cancel: multiple.user.cancel,
                  ),
                  3 => UserOperationView(
                    operation: extended.userState,
                    run: extended.load,
                    cancel: extended.cancel,
                  ),
                  4 => UserOperationView(
                    operation: reactive.operation,
                    run: reactive.load,
                    cancel: reactive.cancel,
                  ),
                  5 => UserOperationView(
                    operation: overridden.operation,
                    run: overridden.load,
                    cancel: overridden.cancel,
                  ),
                  6 => UserOperationView(
                    operation: injected.operation,
                    run: injected.load,
                    cancel: injected.cancel,
                  ),
                  _ => UserOperationView(
                    operation: store.user.state,
                    run: store.load,
                    cancel: store.user.cancel,
                  ),
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UserStore {
  final user = _MobxAsyncOperation<User>();

  Future<void> load() => user.run(MockApiService.fetchUser);

  void dispose() => user.dispose();
}

class _MobxAsyncOperation<T> extends AsyncOperation<T> {
  _MobxAsyncOperation() : _atom = Atom(name: 'AsyncOperation<$T>');

  final Atom _atom;

  @override
  void onRead() {
    _atom.reportRead();
    super.onRead();
  }

  @override
  void onChanged(OperationState<T> previous, OperationState<T> next) {
    super.onChanged(previous, next);
    _atom.reportChanged();
  }
}

class SingleOperationStore with AsyncOperationMixin<User> {
  final _operationAtom = Atom(name: 'SingleOperationStore.operation');

  @override
  OperationState<User> get operation {
    _operationAtom.reportRead();
    return super.operation;
  }

  @override
  Future<User> fetch() => MockApiService.fetchUser();

  @override
  void operationChanged(
    OperationState<User> previous,
    OperationState<User> next,
  ) {
    _operationAtom.reportChanged();
  }

  void dispose() => disposeOperation();
}

abstract final class _MobxOperations {
  static AsyncOperation<T> create<T>({String? name}) {
    final atom = Atom(name: name);
    return AsyncOperation<T>(
      onRead: atom.reportRead,
      onChanged: (_, _) => atom.reportChanged(),
    );
  }
}

class MultipleOperationsStore = _MultipleOperationsStore
    with _$MultipleOperationsStore;

abstract class _MultipleOperationsStore with Store {
  final user = _MobxOperations.create<User>(name: 'user');
  final products = _MobxOperations.create<List<Product>>(name: 'products');

  @computed
  OperationState<User> get userState => user.state;

  @computed
  OperationState<List<Product>> get productsState => products.state;

  Future<void> loadUser() => user.run(MockApiService.fetchUser);

  Future<void> loadProducts() => products.run(MockApiService.fetchProducts);

  void dispose() {
    user.dispose();
    products.dispose();
  }
}

// Store is a mixin, leaving the superclass available for the operation.
class ExtendedOperationStore = _ExtendedOperationStore
    with _$ExtendedOperationStore;

abstract class _ExtendedOperationStore extends _MobxAsyncOperation<User>
    with Store {
  @computed
  OperationState<User> get userState => state;

  Future<void> load() => run(MockApiService.fetchUser);
}

mixin _MobxOperationMixin<T> on AsyncOperationMixin<T> {
  final _atom = Atom(name: 'operation');

  @override
  void operationRead() {
    _atom.reportRead();
    super.operationRead();
  }

  @override
  void operationChanged(OperationState<T> previous, OperationState<T> next) {
    super.operationChanged(previous, next);
    _atom.reportChanged();
  }
}

class ReactiveMixinStore
    with Store, AsyncOperationMixin<User>, _MobxOperationMixin<User> {
  @override
  Future<User> fetch() => MockApiService.fetchUser();
}

class OverriddenControllerStore with Store, AsyncOperationMixin<User> {
  final _user = _MobxAsyncOperation<User>();

  // This controller owns its callbacks rather than using the host hooks.
  @override
  AsyncOperation<User> get operationController => _user;

  @override
  Future<User> fetch() => MockApiService.fetchUser();
}

class InjectedOperationStore with Store, AsyncOperationMixin<User> {
  // Ownership transfers to this store, including disposal and configuration.
  InjectedOperationStore(this.operationController);

  @override
  final AsyncOperation<User> operationController;

  @override
  Future<User> fetch() => MockApiService.fetchUser();
}
