// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'mobx_integration_example.dart';

// **************************************************************************
// StoreGenerator
// **************************************************************************

// ignore_for_file: non_constant_identifier_names, unnecessary_brace_in_string_interps, unnecessary_lambdas, prefer_expression_function_bodies, lines_longer_than_80_chars, avoid_as, avoid_annotating_with_dynamic, no_leading_underscores_for_local_identifiers

mixin _$MultipleOperationsStore on _MultipleOperationsStore, Store {
  Computed<OperationState<User>>? _$userStateComputed;

  @override
  OperationState<User> get userState =>
      (_$userStateComputed ??= Computed<OperationState<User>>(
        () => super.userState,
        name: '_MultipleOperationsStore.userState',
      )).value;
  Computed<OperationState<List<Product>>>? _$productsStateComputed;

  @override
  OperationState<List<Product>> get productsState =>
      (_$productsStateComputed ??= Computed<OperationState<List<Product>>>(
        () => super.productsState,
        name: '_MultipleOperationsStore.productsState',
      )).value;

  @override
  String toString() {
    return '''
userState: ${userState},
productsState: ${productsState}
    ''';
  }
}

mixin _$ExtendedOperationStore on _ExtendedOperationStore, Store {
  Computed<OperationState<User>>? _$userStateComputed;

  @override
  OperationState<User> get userState =>
      (_$userStateComputed ??= Computed<OperationState<User>>(
        () => super.userState,
        name: '_ExtendedOperationStore.userState',
      )).value;

  @override
  String toString() {
    return '''
userState: ${userState}
    ''';
  }
}
