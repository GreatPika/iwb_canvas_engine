final class MutationOwnerPolicySpec {
  const MutationOwnerPolicySpec({
    required this.methodName,
    required this.requiredGuard,
    this.contractKind = MutationOwnerContractKind.standardEffectfulRoute,
  });

  final String methodName;
  final String requiredGuard;
  final MutationOwnerContractKind contractKind;
}

enum MutationOwnerContractKind {
  standardEffectfulRoute,
  cameraOffsetPreflight,
  replaceSceneForwarding,
  publicGuardedBoundaryRoute,
}

final class MutationOwnerGuardSpec {
  const MutationOwnerGuardSpec({
    required this.relativePath,
    required this.className,
    required this.policies,
  });

  final String relativePath;
  final String className;
  final List<MutationOwnerPolicySpec> policies;
}

const String ensureExternalMutationAllowedCall =
    '_ensureExternalMutationAllowed';
const String interruptForExternalMutationCall = '_interruptForExternalMutation';

const List<MutationOwnerPolicySpec> selectionMutationOwnerPolicies =
    <MutationOwnerPolicySpec>[
      MutationOwnerPolicySpec(
        methodName: 'setSelection',
        requiredGuard: ensureExternalMutationAllowedCall,
      ),
      MutationOwnerPolicySpec(
        methodName: 'toggleSelection',
        requiredGuard: ensureExternalMutationAllowedCall,
      ),
      MutationOwnerPolicySpec(
        methodName: 'clearSelection',
        requiredGuard: ensureExternalMutationAllowedCall,
      ),
      MutationOwnerPolicySpec(
        methodName: 'selectAll',
        requiredGuard: ensureExternalMutationAllowedCall,
      ),
      MutationOwnerPolicySpec(
        methodName: 'rotateSelection',
        requiredGuard: ensureExternalMutationAllowedCall,
      ),
      MutationOwnerPolicySpec(
        methodName: 'flipSelectionVertical',
        requiredGuard: ensureExternalMutationAllowedCall,
      ),
      MutationOwnerPolicySpec(
        methodName: 'flipSelectionHorizontal',
        requiredGuard: ensureExternalMutationAllowedCall,
      ),
      MutationOwnerPolicySpec(
        methodName: 'deleteSelection',
        requiredGuard: ensureExternalMutationAllowedCall,
      ),
    ];

const List<MutationOwnerPolicySpec> sceneMutationOwnerPolicies =
    <MutationOwnerPolicySpec>[
      MutationOwnerPolicySpec(
        methodName: 'write',
        requiredGuard: ensureExternalMutationAllowedCall,
      ),
      MutationOwnerPolicySpec(
        methodName: 'setBackgroundColor',
        requiredGuard: ensureExternalMutationAllowedCall,
      ),
      MutationOwnerPolicySpec(
        methodName: 'setGridEnabled',
        requiredGuard: ensureExternalMutationAllowedCall,
      ),
      MutationOwnerPolicySpec(
        methodName: 'setGridCellSize',
        requiredGuard: ensureExternalMutationAllowedCall,
      ),
      MutationOwnerPolicySpec(
        methodName: 'addNode',
        requiredGuard: ensureExternalMutationAllowedCall,
      ),
      MutationOwnerPolicySpec(
        methodName: 'ensureLayer',
        requiredGuard: ensureExternalMutationAllowedCall,
      ),
      MutationOwnerPolicySpec(
        methodName: 'patchNode',
        requiredGuard: ensureExternalMutationAllowedCall,
      ),
      MutationOwnerPolicySpec(
        methodName: 'removeNode',
        requiredGuard: ensureExternalMutationAllowedCall,
      ),
      MutationOwnerPolicySpec(
        methodName: 'clearScene',
        requiredGuard: ensureExternalMutationAllowedCall,
      ),
      MutationOwnerPolicySpec(
        methodName: 'setCameraOffset',
        requiredGuard: interruptForExternalMutationCall,
        contractKind: MutationOwnerContractKind.cameraOffsetPreflight,
      ),
      MutationOwnerPolicySpec(
        methodName: 'replaceScene',
        requiredGuard: interruptForExternalMutationCall,
        contractKind: MutationOwnerContractKind.replaceSceneForwarding,
      ),
      MutationOwnerPolicySpec(
        methodName: 'notifySceneChanged',
        requiredGuard: '',
        contractKind: MutationOwnerContractKind.publicGuardedBoundaryRoute,
      ),
    ];

const List<MutationOwnerGuardSpec> mutationOwnerGuardSpecs =
    <MutationOwnerGuardSpec>[
      MutationOwnerGuardSpec(
        relativePath: 'scene_controller_selection.dart',
        className: 'SceneControllerSelectionOwner',
        policies: selectionMutationOwnerPolicies,
      ),
      MutationOwnerGuardSpec(
        relativePath: 'scene_controller_scene.dart',
        className: 'SceneControllerSceneOwner',
        policies: sceneMutationOwnerPolicies,
      ),
    ];
