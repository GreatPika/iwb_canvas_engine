/// Contract-safe limits shared by public boundary validators.
library;

const int kMaxSvgPathDataLength = 200000;
const int kMaxLayerIdLength = 256;
const int kMaxNodeIdLength = 256;
const int kMaxImageIdLength = 1024;
const int kMaxFontFamilyLength = 256;
const int kMaxTextLength = 100000;

List<int> sceneContractLimitValues() {
  return const <int>[
    kMaxSvgPathDataLength,
    kMaxLayerIdLength,
    kMaxNodeIdLength,
    kMaxImageIdLength,
    kMaxFontFamilyLength,
    kMaxTextLength,
  ];
}
