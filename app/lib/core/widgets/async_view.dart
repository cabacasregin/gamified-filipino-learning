import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Boilerplate-free way to render an [AsyncValue] with consistent
/// loading/error states across the app.
class AsyncView<T> extends StatelessWidget {
  final AsyncValue<T> value;
  final Widget Function(T data) builder;
  final String? emptyMessage;
  final bool Function(T data)? isEmpty;

  const AsyncView({
    super.key,
    required this.value,
    required this.builder,
    this.emptyMessage,
    this.isEmpty,
  });

  @override
  Widget build(BuildContext context) {
    return value.when(
      data: (data) {
        if (isEmpty != null && isEmpty!(data)) {
          return Center(child: Text(emptyMessage ?? 'Wala pang laman dito.'));
        }
        return builder(data);
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 40),
              const SizedBox(height: 12),
              Text('Something went wrong:\n$error', textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}
