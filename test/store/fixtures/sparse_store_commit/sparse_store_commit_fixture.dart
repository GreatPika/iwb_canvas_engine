import 'package:flutter_test/flutter_test.dart';

import 'sparse_store_commit_direct_fixture.dart' as direct;
import 'sparse_store_commit_journal_fixture.dart' as journal;
import 'sparse_store_commit_resource_fixture.dart' as resource;
import 'sparse_store_commit_validation_fixture.dart' as validation;

void main() {
  group('sparse store commit prepare/install', () {
    direct.registerSparseInstallTests();
    resource.registerSparseResourceEditorTests();
    journal.registerSparseAccountingTests();
    validation.registerSparseValidationTests();
  });
}
