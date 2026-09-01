import 'package:iwb_canvas_engine/src/store/document_store_kernel.dart'
    show DocumentStoreKernel, IdAdmissionWorkEvent;
import 'package:iwb_canvas_engine/src/store/id_admission.dart'
    show IdAdmissionWorkKind, IdAdmissionWorkPhase;

/// Captures Store-owned ID-admission work while a scenario executes.
///
/// Scenarios retain their own expected phase maps; this support type only
/// records the one existing Store observation stream.
final class IdAdmissionWorkRecorder {
  final Map<(String, IdAdmissionWorkPhase, IdAdmissionWorkKind), int> _counts =
      {};

  void record(IdAdmissionWorkEvent event) {
    final key = (event.prefix, event.phase, event.kind);
    _counts[key] = (_counts[key] ?? 0) + 1;
  }

  int count({
    required String prefix,
    required IdAdmissionWorkPhase phase,
    required IdAdmissionWorkKind kind,
  }) {
    return _counts[(prefix, phase, kind)] ?? 0;
  }
}

IdAdmissionWorkRecorder observeIdAdmissionWork(void Function() operation) {
  final recorder = IdAdmissionWorkRecorder();
  DocumentStoreKernel.observeIdAdmissionWork(recorder.record, operation);
  return recorder;
}
