import '../contract/ids.dart' show LayerId;

typedef NodeLocatorEntry = ({LayerId? contentLayerId, int nodeIndex});

NodeLocatorEntry nodeLocatorEntry({
  required LayerId? contentLayerId,
  required int nodeIndex,
}) {
  return (contentLayerId: contentLayerId, nodeIndex: nodeIndex);
}
