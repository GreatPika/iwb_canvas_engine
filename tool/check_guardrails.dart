import 'src/guardrails/guardrails_runner.dart';

// Invariants enforced by this tool:
// INV:INV-ENG-WRITE-ONLY-MUTATION
// INV:INV-ENG-SAFE-TXN-API
// INV:INV-ENG-INTERACTIVE-RESOLVER-PURITY
// INV:INV-ENG-MODEL-ARCHITECTURE-BOUNDARY
// INV:INV-ENG-CONTRACT-ARCHITECTURE-BOUNDARY

Future<void> main(List<String> _) => runGuardrailsTool();
