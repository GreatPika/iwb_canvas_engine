final class MutationOwnerPolicySpec {
  const MutationOwnerPolicySpec({
    required this.methodName,
    required this.policyIndex,
    required this.policyCall,
  });

  final String methodName;
  final int policyIndex;
  final String policyCall;
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
    'ensureExternalMutationAllowed';
const String interruptForExternalMutationCall = 'interruptForExternalMutation';

const List<MutationOwnerPolicySpec> selectionMutationOwnerPolicies =
    <MutationOwnerPolicySpec>[
      MutationOwnerPolicySpec(
        methodName: 'setSelection',
        policyIndex: 0,
        policyCall: ensureExternalMutationAllowedCall,
      ),
      MutationOwnerPolicySpec(
        methodName: 'toggleSelection',
        policyIndex: 0,
        policyCall: ensureExternalMutationAllowedCall,
      ),
      MutationOwnerPolicySpec(
        methodName: 'clearSelection',
        policyIndex: 0,
        policyCall: ensureExternalMutationAllowedCall,
      ),
      MutationOwnerPolicySpec(
        methodName: 'selectAll',
        policyIndex: 0,
        policyCall: ensureExternalMutationAllowedCall,
      ),
      MutationOwnerPolicySpec(
        methodName: 'rotateSelection',
        policyIndex: 0,
        policyCall: ensureExternalMutationAllowedCall,
      ),
      MutationOwnerPolicySpec(
        methodName: 'flipSelectionVertical',
        policyIndex: 0,
        policyCall: ensureExternalMutationAllowedCall,
      ),
      MutationOwnerPolicySpec(
        methodName: 'flipSelectionHorizontal',
        policyIndex: 0,
        policyCall: ensureExternalMutationAllowedCall,
      ),
      MutationOwnerPolicySpec(
        methodName: 'deleteSelection',
        policyIndex: 0,
        policyCall: ensureExternalMutationAllowedCall,
      ),
    ];

const List<MutationOwnerPolicySpec> sceneMutationOwnerPolicies =
    <MutationOwnerPolicySpec>[
      MutationOwnerPolicySpec(
        methodName: 'write',
        policyIndex: 0,
        policyCall: ensureExternalMutationAllowedCall,
      ),
      MutationOwnerPolicySpec(
        methodName: 'setBackgroundColor',
        policyIndex: 0,
        policyCall: ensureExternalMutationAllowedCall,
      ),
      MutationOwnerPolicySpec(
        methodName: 'setGridEnabled',
        policyIndex: 0,
        policyCall: ensureExternalMutationAllowedCall,
      ),
      MutationOwnerPolicySpec(
        methodName: 'setGridCellSize',
        policyIndex: 0,
        policyCall: ensureExternalMutationAllowedCall,
      ),
      MutationOwnerPolicySpec(
        methodName: 'addNode',
        policyIndex: 0,
        policyCall: ensureExternalMutationAllowedCall,
      ),
      MutationOwnerPolicySpec(
        methodName: 'ensureLayer',
        policyIndex: 0,
        policyCall: ensureExternalMutationAllowedCall,
      ),
      MutationOwnerPolicySpec(
        methodName: 'patchNode',
        policyIndex: 0,
        policyCall: ensureExternalMutationAllowedCall,
      ),
      MutationOwnerPolicySpec(
        methodName: 'removeNode',
        policyIndex: 0,
        policyCall: ensureExternalMutationAllowedCall,
      ),
      MutationOwnerPolicySpec(
        methodName: 'clearScene',
        policyIndex: 0,
        policyCall: ensureExternalMutationAllowedCall,
      ),
      MutationOwnerPolicySpec(
        methodName: 'setCameraOffset',
        policyIndex: 2,
        policyCall: interruptForExternalMutationCall,
      ),
      MutationOwnerPolicySpec(
        methodName: 'replaceScene',
        policyIndex: 1,
        policyCall: interruptForExternalMutationCall,
      ),
    ];

const List<MutationOwnerGuardSpec> mutationOwnerGuardSpecs =
    <MutationOwnerGuardSpec>[
      MutationOwnerGuardSpec(
        relativePath: 'internal/scene_controller_selection_mutations.dart',
        className: 'SceneControllerSelectionMutations',
        policies: selectionMutationOwnerPolicies,
      ),
      MutationOwnerGuardSpec(
        relativePath: 'internal/scene_controller_scene_mutations.dart',
        className: 'SceneControllerSceneMutations',
        policies: sceneMutationOwnerPolicies,
      ),
    ];
