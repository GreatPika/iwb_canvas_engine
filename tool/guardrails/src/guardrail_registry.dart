import 'guardrail_definition.dart';
import 'public_api/public_api_boundary_check.dart';

List<GuardrailDefinition> publicApiGuardrails() {
  return <GuardrailDefinition>[
    GuardrailDefinition(
      id: 'api.no_legacy_public_types',
      suite: 'api',
      description: 'Legacy public golden symbols are absent from root exports.',
      run: (root) => PublicApiBoundaryCheck(root).noLegacyPublicTypes(),
    ),
    GuardrailDefinition(
      id: 'api.public_exports_complete',
      suite: 'api',
      description: 'The public barrel exports every registry-owned API name.',
      run: (root) => PublicApiBoundaryCheck(root).publicExportsComplete(),
    ),
    GuardrailDefinition(
      id: 'api.public_types_complete',
      suite: 'api',
      description: 'Exported signatures reference defined public types only.',
      run: (root) => PublicApiBoundaryCheck(root).publicTypesComplete(),
    ),
  ];
}
