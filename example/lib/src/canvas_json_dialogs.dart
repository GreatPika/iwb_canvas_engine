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
    builder: (context) => _JsonExportDialog(json: json),
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

final class _JsonExportDialog extends StatelessWidget {
  const _JsonExportDialog({required this.json});

  final String json;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Export JSON'),
      content: _JsonExportContent(json: json),
      actions: [
        _CopyJsonButton(json: json),
        const _CloseDialogButton(),
      ],
    );
  }
}

final class _JsonExportContent extends StatelessWidget {
  const _JsonExportContent({required this.json});

  final String json;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 560,
      child: SingleChildScrollView(
        key: const ValueKey('json.export.text'),
        child: SelectableText(json),
      ),
    );
  }
}

final class _CopyJsonButton extends StatelessWidget {
  const _CopyJsonButton({required this.json});

  final String json;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      key: const ValueKey('json.export.copy'),
      onPressed: () => Clipboard.setData(ClipboardData(text: json)),
      child: const Text('Copy'),
    );
  }
}

final class _CloseDialogButton extends StatelessWidget {
  const _CloseDialogButton();

  @override
  Widget build(BuildContext context) {
    return TextButton(
      key: const ValueKey('json.export.close'),
      onPressed: () => Navigator.of(context).pop(),
      child: const Text('Close'),
    );
  }
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
    return _JsonImportDialogContent(controller: _controller, onSubmit: _submit);
  }

  void _submit() {
    if (widget.viewModel.importDocumentJson(_controller.text)) {
      Navigator.of(context).pop();
    }
  }
}

final class _JsonImportDialogContent extends StatelessWidget {
  const _JsonImportDialogContent({
    required this.controller,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Import JSON'),
      content: _JsonImportField(controller: controller),
      actions: [
        TextButton(
          key: const ValueKey('json.import.submit'),
          onPressed: onSubmit,
          child: const Text('Import'),
        ),
        TextButton(
          key: const ValueKey('json.import.cancel'),
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}

final class _JsonImportField extends StatelessWidget {
  const _JsonImportField({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 560,
      child: TextField(
        key: const ValueKey('json.import.text'),
        controller: controller,
        maxLines: 12,
        decoration: const InputDecoration(border: OutlineInputBorder()),
      ),
    );
  }
}
