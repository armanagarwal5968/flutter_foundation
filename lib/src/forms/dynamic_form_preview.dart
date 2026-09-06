import 'package:flutter/material.dart';

import 'dynamic_form_definition.dart';
import 'dynamic_form_view.dart';

/// Renders a form exactly as an end user sees it without saving a response.
class DynamicFormPreviewPage extends StatelessWidget {
  const DynamicFormPreviewPage({required this.definition, super.key});

  final DynamicFormDefinition definition;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Preview: ${definition.title}')),
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: Theme.of(context).colorScheme.secondaryContainer,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: const Text(
              'Preview mode — responses are not saved.',
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: DynamicFormView(
              definition: definition,
              onSubmit: (_) async {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Preview completed. Nothing was saved.'),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
