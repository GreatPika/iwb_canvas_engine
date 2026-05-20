final class PublicApiPlaceholder {
  const PublicApiPlaceholder({
    required this.declarationId,
    required this.ownerPhase,
    required this.reason,
    required this.removalCondition,
  });

  final String declarationId;
  final String ownerPhase;
  final String reason;
  final String removalCondition;
}

const publicApiPlaceholderAllowlist = <PublicApiPlaceholder>[
  PublicApiPlaceholder(
    declarationId: 'CanvasRuntime.edits',
    ownerPhase: 'P5',
    reason: 'Edit mutation behavior is owned by the edit core phase.',
    removalCondition: 'Remove when CanvasEditPort is backed by edit core.',
  ),
  PublicApiPlaceholder(
    declarationId: 'CanvasRuntime.selection',
    ownerPhase: 'P10',
    reason: 'Selection behavior is owned by the selection phase.',
    removalCondition:
        'Remove when CanvasSelectionPort is backed by runtime state.',
  ),
  PublicApiPlaceholder(
    declarationId: 'CanvasRuntime.tools',
    ownerPhase: 'P11',
    reason: 'Tool behavior is owned by draw tools.',
    removalCondition:
        'Remove when CanvasToolPort is backed by tool runtime state.',
  ),
  PublicApiPlaceholder(
    declarationId: 'CanvasRuntime.commands',
    ownerPhase: 'P5',
    reason: 'Command behavior depends on edit core ownership.',
    removalCondition:
        'Remove when CanvasCommandPort executes committed mutations.',
  ),
  PublicApiPlaceholder(
    declarationId: 'CanvasRuntime.camera',
    ownerPhase: 'P4',
    reason: 'Runtime camera mutation is owned by the runtime spine.',
    removalCondition:
        'Remove when CanvasCameraPort is backed by runtime state.',
  ),
  PublicApiPlaceholder(
    declarationId: 'CanvasRuntime.resources',
    ownerPhase: 'P7',
    reason: 'Resource runtime behavior is owned by resources and images.',
    removalCondition:
        'Remove when CanvasResourcePort is backed by resource state.',
  ),
  PublicApiPlaceholder(
    declarationId: 'CanvasRuntime.preview',
    ownerPhase: 'P11',
    reason: 'Preview production is owned by draw tools.',
    removalCondition:
        'Remove when runtime publishes real CanvasPreviewState values.',
  ),
  PublicApiPlaceholder(
    declarationId: 'CanvasRuntime.actions',
    ownerPhase: 'P5',
    reason: 'Action stream events depend on committed edit operations.',
    removalCondition: 'Remove when committed actions are emitted by edit core.',
  ),
  PublicApiPlaceholder(
    declarationId: 'CanvasRuntime.contextActionRequests',
    ownerPhase: 'P12',
    reason:
        'Context action request emission is owned by text request handling.',
    removalCondition:
        'Remove when text request runtime behavior is implemented.',
  ),
  PublicApiPlaceholder(
    declarationId: 'CanvasRuntime.generateElementId',
    ownerPhase: 'P4',
    reason: 'Id generation is owned by runtime spine document ownership.',
    removalCondition:
        'Remove when runtime owns committed document id allocation.',
  ),
  PublicApiPlaceholder(
    declarationId: 'CanvasRuntime.generateLayerId',
    ownerPhase: 'P4',
    reason: 'Id generation is owned by runtime spine document ownership.',
    removalCondition:
        'Remove when runtime owns committed document id allocation.',
  ),
  PublicApiPlaceholder(
    declarationId: 'CanvasRuntime.generateResourceId',
    ownerPhase: 'P7',
    reason: 'Resource id generation is owned by resources and images.',
    removalCondition: 'Remove when runtime owns resource id allocation.',
  ),
  PublicApiPlaceholder(
    declarationId: 'CanvasRuntime.dispose',
    ownerPhase: 'P4',
    reason: 'Lifecycle behavior is owned by runtime spine.',
    removalCondition: 'Remove when runtime disposal closes streams and state.',
  ),
  PublicApiPlaceholder(
    declarationId: 'encodeCanvasDocument',
    ownerPhase: 'P3',
    reason: 'Schema v1 encoding is owned by codec skeleton and validation.',
    removalCondition: 'Remove when schema v1 document encoding is implemented.',
  ),
  PublicApiPlaceholder(
    declarationId: 'encodeCanvasDocumentToJson',
    ownerPhase: 'P3',
    reason:
        'Schema v1 JSON encoding is owned by codec skeleton and validation.',
    removalCondition: 'Remove when schema v1 JSON encoding is implemented.',
  ),
  PublicApiPlaceholder(
    declarationId: 'CanvasSurface.build',
    ownerPhase: 'P13',
    reason: 'Flutter surface rendering is owned by the Flutter surface phase.',
    removalCondition:
        'Remove when CanvasSurface renders and attaches runtime listeners.',
  ),
];
