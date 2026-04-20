part of 'mutation_boundary_rules.dart';

Future<GuardrailViolation?> _checkMutationOwnerPolicies(
  GuardrailContext context,
) async {
  for (final spec in mutationOwnerGuardSpecs) {
    final file = _interactiveSupportFile(context, spec.relativePath);
    if (!file.existsSync()) {
      return GuardrailViolation(
        filePath: _interactiveFilePosixPath(context, _interactiveFile(context)),
        line: 1,
        message:
            'interactive API violation: missing required mutation owner '
            '${spec.className} at ${_interactiveFilePosixPath(context, file)}.',
      );
    }

    final filePath = _interactiveFilePosixPath(context, file);
    final resolved = await _resolveInteractiveUnitOrFail(
      context: context,
      file: file,
      filePath: filePath,
    );
    final ownerClass = _findClassByName(
      resolved.unit.declarations,
      spec.className,
    );
    if (ownerClass == null) {
      return GuardrailViolation(
        filePath: filePath,
        line: 1,
        message:
            'interactive API violation: ${spec.className} must remain the '
            'canonical mutation owner in $filePath.',
      );
    }

    for (final policy in spec.policies) {
      final member = _findMethodByName(ownerClass.members, policy.methodName);
      if (member == null) {
        return GuardrailViolation(
          filePath: filePath,
          line: 1,
          message:
              'interactive API violation: '
              '${spec.className}.${policy.methodName} '
              'must remain part of the canonical mutation-owner surface.',
        );
      }
      final violation = _checkMutationOwnerPolicy(
        context: context,
        member: member,
        filePath: filePath,
        lineFor: (offset) => _lineForResolvedOffset(resolved, offset),
        className: spec.className,
        policy: policy,
      );
      if (violation != null) {
        return violation;
      }
    }
  }
  return null;
}

GuardrailViolation? _checkMutationOwnerPolicy({
  required GuardrailContext context,
  required MethodDeclaration member,
  required String filePath,
  required int Function(int offset) lineFor,
  required String className,
  required MutationOwnerPolicySpec policy,
}) {
  final body = member.body;
  if (body is! BlockFunctionBody) {
    return _mutationOwnerPolicyViolation(
      filePath: filePath,
      line: lineFor(member.offset),
      className: className,
      methodName: policy.methodName,
      requiredGuard: policy.requiredGuard,
    );
  }

  switch (policy.contractKind) {
    case MutationOwnerContractKind.standardEffectfulRoute:
      return _checkStandardMutationOwnerPolicy(
        context: context,
        body: body,
        member: member,
        filePath: filePath,
        lineFor: lineFor,
        className: className,
        policy: policy,
      );
    case MutationOwnerContractKind.cameraOffsetPreflight:
      return _checkSetCameraOffsetMutationOwnerPolicy(
        context: context,
        body: body,
        member: member,
        filePath: filePath,
        lineFor: lineFor,
        className: className,
        policy: policy,
      );
    case MutationOwnerContractKind.replaceSceneForwarding:
      return _checkReplaceSceneMutationOwnerPolicy(
        context: context,
        body: body,
        member: member,
        filePath: filePath,
        lineFor: lineFor,
        className: className,
        policy: policy,
      );
  }
}

GuardrailViolation? _checkStandardMutationOwnerPolicy({
  required GuardrailContext context,
  required BlockFunctionBody body,
  required MethodDeclaration member,
  required String filePath,
  required int Function(int offset) lineFor,
  required String className,
  required MutationOwnerPolicySpec policy,
}) {
  final events = body.block.statements
      .map(
        (statement) => _classifyMutationOwnerStatement(
          statement: statement,
          context: context,
          filePath: filePath,
          className: className,
          requiredGuard: policy.requiredGuard,
        ),
      )
      .toList(growable: false);
  return _evaluateMutationOwnerGuardedSequence(
    events: events,
    filePath: filePath,
    lineFor: lineFor,
    missingGuardOffset: member.offset,
    className: className,
    methodName: policy.methodName,
    requiredGuard: policy.requiredGuard,
  );
}

GuardrailViolation? _checkSetCameraOffsetMutationOwnerPolicy({
  required GuardrailContext context,
  required BlockFunctionBody body,
  required MethodDeclaration member,
  required String filePath,
  required int Function(int offset) lineFor,
  required String className,
  required MutationOwnerPolicySpec policy,
}) {
  final events = body.block.statements
      .map(
        (statement) => _classifySetCameraOffsetStatement(
          statement: statement,
          context: context,
          filePath: filePath,
          className: className,
          requiredGuard: policy.requiredGuard,
        ),
      )
      .toList(growable: false);
  return _evaluateSetCameraOffsetSequence(
    events: events,
    filePath: filePath,
    lineFor: lineFor,
    missingGuardOffset: member.offset,
    className: className,
    methodName: policy.methodName,
    requiredGuard: policy.requiredGuard,
  );
}

GuardrailViolation? _checkReplaceSceneMutationOwnerPolicy({
  required GuardrailContext context,
  required BlockFunctionBody body,
  required MethodDeclaration member,
  required String filePath,
  required int Function(int offset) lineFor,
  required String className,
  required MutationOwnerPolicySpec policy,
}) {
  var sawForwarding = false;
  for (final statement in body.block.statements) {
    if (!sawForwarding && _isAllowedPurePreGuardStatement(statement)) {
      continue;
    }
    if (!sawForwarding &&
        _isAllowedReplaceSceneForwardingStatement(
          statement: statement,
          context: context,
          filePath: filePath,
          className: className,
          requiredGuard: policy.requiredGuard,
        )) {
      sawForwarding = true;
      continue;
    }
    return _mutationOwnerPolicyViolation(
      filePath: filePath,
      line: lineFor(statement.offset),
      className: className,
      methodName: policy.methodName,
      requiredGuard: policy.requiredGuard,
    );
  }
  return sawForwarding
      ? null
      : _mutationOwnerPolicyViolation(
          filePath: filePath,
          line: lineFor(member.offset),
          className: className,
          methodName: policy.methodName,
          requiredGuard: policy.requiredGuard,
        );
}
