import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'canvas_example_view_model.dart';

Future<void> showCanvasJsonExportDialog(
  BuildContext context,
  CanvasExampleViewModel viewModel,
) {
  final json = viewModel.exportDocumentJson();

  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Scene JSON'),
      content: SizedBox(
        width: 400,
        child: TextField(
          key: const ValueKey('json.export.text'),
          controller: TextEditingController(text: json),
          maxLines: 8,
          readOnly: true,
        ),
      ),
      actions: [
        TextButton(
          key: const ValueKey('json.export.copy'),
          onPressed: () {
            unawaited(Clipboard.setData(ClipboardData(text: json)));
            Navigator.pop(context);
          },
          child: const Text('Copy'),
        ),
        TextButton(
          key: const ValueKey('json.export.close'),
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}

Future<void> showCanvasJsonImportDialog(
  BuildContext context,
  CanvasExampleViewModel viewModel,
) {
  return showDialog<void>(
    context: context,
    builder: (context) => _JsonImportDialog(viewModel: viewModel),
  );
}

final class _JsonImportDialog extends StatefulWidget {
  const _JsonImportDialog({required this.viewModel});

  final CanvasExampleViewModel viewModel;

  @override
  State<_JsonImportDialog> createState() => _JsonImportDialogState();
}

final class _JsonImportDialogState extends State<_JsonImportDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.viewModel.lastExportedJson ?? '',
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Import Scene'),
      content: TextField(
        key: const ValueKey('json.import.text'),
        controller: _controller,
        maxLines: 8,
      ),
      actions: [
        TextButton(
          key: const ValueKey('json.import.cancel'),
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: const ValueKey('json.import.submit'),
          onPressed: _submit,
          child: const Text('Import'),
        ),
      ],
    );
  }

  void _submit() {
    if (widget.viewModel.importDocumentJson(_controller.text)) {
      Navigator.pop(context);
    }
  }
}
