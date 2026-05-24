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
    declarationId: 'CanvasRuntime.contextActionRequests',
    ownerPhase: 'P12',
    reason:
        'Context action request emission is owned by text request handling.',
    removalCondition:
        'Remove when text request runtime behavior is implemented.',
  ),
  PublicApiPlaceholder(
    declarationId: 'CanvasSurface.build',
    ownerPhase: 'P13',
    reason: 'Flutter surface rendering is owned by the Flutter surface phase.',
    removalCondition:
        'Remove when CanvasSurface renders and attaches runtime listeners.',
  ),
];
