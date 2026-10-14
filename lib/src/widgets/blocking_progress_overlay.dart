import 'package:flutter/material.dart';

/// Blocks interaction while an asynchronous action is in progress and explains
/// what the app is waiting for.
class BlockingProgressOverlay extends StatelessWidget {
  const BlockingProgressOverlay({
    required this.visible,
    required this.message,
    required this.child,
    super.key,
  });

  final bool visible;
  final String message;
  final Widget child;

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      child,
      if (visible) ...[
        const Positioned.fill(
          child: ModalBarrier(
            key: Key('blocking-progress-barrier'),
            dismissible: false,
            color: Colors.black45,
          ),
        ),
        Positioned.fill(
          child: Center(
            child: Semantics(
              liveRegion: true,
              label: message,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 24,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 16),
                      Text(
                        message,
                        key: const Key('blocking-progress-message'),
                        style: Theme.of(context).textTheme.titleMedium,
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    ],
  );
}
