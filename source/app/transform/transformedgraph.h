#ifndef TRANSFORMEDGRAPH_H
#define TRANSFORMEDGRAPH_H

#include "graphtransform.h"

#include "graph/graph.h"
#include "graph/mutablegraph.h"
#include "shared/graph/grapharray.h"

#include <QObject>

#include <functional>

class TransformedGraph : public Graph
{
    Q_OBJECT

public:
    explicit TransformedGraph(const Graph& source);

    void enableAutoRebuild() { _autoRebuild = true; }
    void setTransform(std::unique_ptr<GraphTransform> graphTransform);

    const std::vector<NodeId>& nodeIds() const { return _target.nodeIds(); }
    int numNodes() const { return _target.numNodes(); }
    const INode& nodeById(NodeId nodeId) const { return _target.nodeById(nodeId); }
    bool containsNodeId(NodeId nodeId) const { return _target.containsNodeId(nodeId); }
    NodeIdDistinctSetCollection::Type typeOf(NodeId nodeId) const { return _target.typeOf(nodeId); }
    ConstNodeIdDistinctSet mergedNodeIdsForNodeId(NodeId nodeId) const { return _target.mergedNodeIdsForNodeId(nodeId); }

    const std::vector<EdgeId>& edgeIds() const { return _target.edgeIds(); }
    int numEdges() const { return _target.numEdges(); }
    const IEdge& edgeById(EdgeId edgeId) const { return _target.edgeById(edgeId); }
    bool containsEdgeId(EdgeId edgeId) const { return _target.containsEdgeId(edgeId); }
    EdgeIdDistinctSetCollection::Type typeOf(EdgeId edgeId) const { return _target.typeOf(edgeId); }
    ConstEdgeIdDistinctSet mergedEdgeIdsForEdgeId(EdgeId edgeId) const { return _target.mergedEdgeIdsForEdgeId(edgeId); }

    EdgeIdDistinctSets edgeIdsForNodeId(NodeId nodeId) const { return _target.edgeIdsForNodeId(nodeId); }

    void setPhase(const QString& phase) const { _source->setPhase(phase); }
    void clearPhase() const { _source->clearPhase(); }
    QString phase() const { return _source->phase(); }

    void setSubPhase(const QString& subPhase) const { _source->setSubPhase(subPhase); }
    void clearSubPhase() const { _source->clearSubPhase(); }
    QString subPhase() const { return _source->subPhase(); }

    MutableGraph& mutableGraph() { return _target; }

    void reserve(const Graph& other);
    void cloneFrom(const Graph& other);

    void update() { _target.update(); }

private:
    const Graph* _source;
    std::unique_ptr<GraphTransform> _graphTransform;
    MutableGraph _target;
    bool _autoRebuild = false;

    class State
    {
    private:
        enum class Value { Removed, Unchanged, Added };
        Value state = Value::Unchanged;

    public:
        void add()     { state = state == Value::Removed ? Value::Unchanged : Value::Added; }
        void remove()  { state = state == Value::Added ?   Value::Unchanged : Value::Removed; }

        bool added() const   { return state == Value::Added; }
        bool removed() const { return state == Value::Removed; }
    };

    NodeArray<State> _nodesState;
    EdgeArray<State> _edgesState;
    NodeArray<State> _previousNodesState;
    EdgeArray<State> _previousEdgesState;

    void rebuild();

private slots:
    void onTargetGraphChanged(const Graph* graph);
};

#endif // TRANSFORMEDGRAPH_H
