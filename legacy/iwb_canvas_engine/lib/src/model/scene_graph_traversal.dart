typedef SceneGraphNodeMapper<TSourceNode, TTargetNode> =
    TTargetNode Function(TSourceNode node);

typedef SceneGraphBackgroundNodes<TBackgroundLayer, TSourceNode> =
    Iterable<TSourceNode> Function(TBackgroundLayer layer);

typedef SceneGraphContentNodes<TContentLayer, TSourceNode> =
    Iterable<TSourceNode> Function(TContentLayer layer);

typedef SceneGraphBackgroundLayerBuilder<
  TBackgroundLayer,
  TTargetBackgroundLayer,
  TTargetNode
> =
    TTargetBackgroundLayer Function(
      TBackgroundLayer layer,
      List<TTargetNode> nodes,
    );

typedef SceneGraphContentLayerBuilder<
  TContentLayer,
  TTargetContentLayer,
  TTargetNode
> = TTargetContentLayer Function(TContentLayer layer, List<TTargetNode> nodes);

typedef SceneGraphResultBuilder<
  TResult,
  TTargetBackgroundLayer,
  TTargetContentLayer,
  TCamera,
  TBackground,
  TPalette
> =
    TResult Function({
      required TTargetBackgroundLayer? backgroundLayer,
      required List<TTargetContentLayer> layers,
      required TCamera camera,
      required TBackground background,
      required TPalette palette,
    });

final class SceneGraphTraversalSource<
  TBackgroundLayer,
  TContentLayer,
  TSourceNode
> {
  const SceneGraphTraversalSource({
    required this.backgroundLayer,
    required this.layers,
    required this.backgroundNodesOf,
    required this.contentNodesOf,
  });

  final TBackgroundLayer? backgroundLayer;
  final Iterable<TContentLayer> layers;
  final SceneGraphBackgroundNodes<TBackgroundLayer, TSourceNode>
  backgroundNodesOf;
  final SceneGraphContentNodes<TContentLayer, TSourceNode> contentNodesOf;
}

final class SceneGraphTraversalStrategy<
  TResult,
  TBackgroundLayer,
  TContentLayer,
  TSourceNode,
  TTargetNode,
  TTargetBackgroundLayer,
  TTargetContentLayer,
  TCamera,
  TBackground,
  TPalette
> {
  const SceneGraphTraversalStrategy({
    required this.mapNode,
    required this.buildBackgroundLayer,
    required this.buildContentLayer,
    required this.buildCamera,
    required this.buildBackground,
    required this.buildPalette,
    required this.buildResult,
  });

  final SceneGraphNodeMapper<TSourceNode, TTargetNode> mapNode;
  final SceneGraphBackgroundLayerBuilder<
    TBackgroundLayer,
    TTargetBackgroundLayer,
    TTargetNode
  >
  buildBackgroundLayer;
  final SceneGraphContentLayerBuilder<
    TContentLayer,
    TTargetContentLayer,
    TTargetNode
  >
  buildContentLayer;
  final TCamera Function() buildCamera;
  final TBackground Function() buildBackground;
  final TPalette Function() buildPalette;
  final SceneGraphResultBuilder<
    TResult,
    TTargetBackgroundLayer,
    TTargetContentLayer,
    TCamera,
    TBackground,
    TPalette
  >
  buildResult;
}

TResult traverseSceneGraph<
  TResult,
  TBackgroundLayer,
  TContentLayer,
  TSourceNode,
  TTargetNode,
  TTargetBackgroundLayer,
  TTargetContentLayer,
  TCamera,
  TBackground,
  TPalette
>({
  required SceneGraphTraversalSource<
    TBackgroundLayer,
    TContentLayer,
    TSourceNode
  >
  source,
  required SceneGraphTraversalStrategy<
    TResult,
    TBackgroundLayer,
    TContentLayer,
    TSourceNode,
    TTargetNode,
    TTargetBackgroundLayer,
    TTargetContentLayer,
    TCamera,
    TBackground,
    TPalette
  >
  strategy,
}) {
  return strategy.buildResult(
    backgroundLayer: _traverseBackgroundLayer(
      source: source,
      strategy: strategy,
    ),
    layers: _traverseContentLayers(source: source, strategy: strategy),
    camera: strategy.buildCamera(),
    background: strategy.buildBackground(),
    palette: strategy.buildPalette(),
  );
}

TTargetBackgroundLayer? _traverseBackgroundLayer<
  TResult,
  TBackgroundLayer,
  TContentLayer,
  TSourceNode,
  TTargetNode,
  TTargetBackgroundLayer,
  TTargetContentLayer,
  TCamera,
  TBackground,
  TPalette
>({
  required SceneGraphTraversalSource<
    TBackgroundLayer,
    TContentLayer,
    TSourceNode
  >
  source,
  required SceneGraphTraversalStrategy<
    TResult,
    TBackgroundLayer,
    TContentLayer,
    TSourceNode,
    TTargetNode,
    TTargetBackgroundLayer,
    TTargetContentLayer,
    TCamera,
    TBackground,
    TPalette
  >
  strategy,
}) {
  final sourceBackgroundLayer = source.backgroundLayer;
  if (sourceBackgroundLayer == null) {
    return null;
  }
  return strategy.buildBackgroundLayer(
    sourceBackgroundLayer,
    source
        .backgroundNodesOf(sourceBackgroundLayer)
        .map(strategy.mapNode)
        .toList(growable: false),
  );
}

List<TTargetContentLayer> _traverseContentLayers<
  TResult,
  TBackgroundLayer,
  TContentLayer,
  TSourceNode,
  TTargetNode,
  TTargetBackgroundLayer,
  TTargetContentLayer,
  TCamera,
  TBackground,
  TPalette
>({
  required SceneGraphTraversalSource<
    TBackgroundLayer,
    TContentLayer,
    TSourceNode
  >
  source,
  required SceneGraphTraversalStrategy<
    TResult,
    TBackgroundLayer,
    TContentLayer,
    TSourceNode,
    TTargetNode,
    TTargetBackgroundLayer,
    TTargetContentLayer,
    TCamera,
    TBackground,
    TPalette
  >
  strategy,
}) {
  return source.layers
      .map(
        (layer) => strategy.buildContentLayer(
          layer,
          source
              .contentNodesOf(layer)
              .map(strategy.mapNode)
              .toList(growable: false),
        ),
      )
      .toList(growable: false);
}
