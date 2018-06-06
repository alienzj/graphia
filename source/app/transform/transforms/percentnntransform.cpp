#include "percentnntransform.h"

#include "transform/transformedgraph.h"
#include "graph/graphmodel.h"
#include "shared/utils/container.h"

#include <algorithm>
#include <functional>
#include <memory>

#include <QObject>

void PercentNNTransform::apply(TransformedGraph& target) const
{
    target.setPhase(QObject::tr("%-NN"));

    const auto attributeNames = config().attributeNames();

    if(attributeNames.empty())
    {
        addAlert(AlertType::Error, QObject::tr("Invalid parameter"));
        return;
    }

    auto attributeName = attributeNames.front();

    auto percent = static_cast<size_t>(boost::get<int>(config().parameterByName(QStringLiteral("Percent"))->_value));
    auto minimum = static_cast<size_t>(boost::get<int>(config().parameterByName(QStringLiteral("Minimum"))->_value));

    if(hasUnknownAttributes({attributeName}, *_graphModel))
        return;

    auto attribute = _graphModel->attributeValueByName(attributeName);
    bool ignoreTails = attribute.testFlag(AttributeFlag::IgnoreTails);
    bool ascending = config().parameterHasValue(QStringLiteral("Rank Order"), QStringLiteral("Ascending"));

    struct PercentNNRank
    {
        size_t _source = 0;
        size_t _target = 0;
        double _mean = 0.0;
    };

    EdgeArray<PercentNNRank> ranks(target);
    EdgeArray<bool> removees(target, true);

    uint64_t progress = 0;
    for(auto nodeId : target.nodeIds())
    {
        auto edgeIds = target.nodeById(nodeId).edgeIds();

        if(ignoreTails)
        {
            edgeIds.erase(std::remove_if(edgeIds.begin(), edgeIds.end(),
            [&target](auto edgeId)
            {
                return target.typeOf(edgeId) == MultiElementType::Tail;
            }), edgeIds.end());
        }

        auto k = std::max((edgeIds.size() * percent) / 100, minimum);
        auto kthPlus1 = edgeIds.begin() + std::min(k, edgeIds.size());

        if(ascending)
        {
            std::partial_sort(edgeIds.begin(), kthPlus1, edgeIds.end(),
                [&attribute](auto a, auto b) { return attribute.numericValueOf(a) < attribute.numericValueOf(b); });
        }
        else
        {
            std::partial_sort(edgeIds.begin(), kthPlus1, edgeIds.end(),
                [&attribute](auto a, auto b) { return attribute.numericValueOf(a) > attribute.numericValueOf(b); });
        }

        for(auto it = edgeIds.begin(); it != kthPlus1; ++it)
        {
            auto position = std::distance(edgeIds.begin(), it) + 1;

            if(target.edgeById(*it).sourceId() == nodeId)
                ranks[*it]._source = position;
            else
                ranks[*it]._target = position;

            removees.set(*it, false);
        }

        target.setProgress((progress++ * 100) / target.numNodes());
    }

    progress = 0;

    for(const auto& edgeId : target.edgeIds())
    {
        if(removees.get(edgeId))
        {
            if(ignoreTails && target.typeOf(edgeId) == MultiElementType::Tail)
                continue;

            target.mutableGraph().removeEdge(edgeId);
        }
        else
        {
            auto& rank = ranks[edgeId];

            if(rank._source == 0)
                rank._mean = rank._target;
            else if(rank._target == 0)
                rank._mean = rank._source;
            else
                rank._mean = (rank._source + rank._target) * 0.5;
        }

        target.setProgress((progress++ * 100) / target.numEdges());
    }

    target.setProgress(-1);

    _graphModel->createAttribute(QObject::tr("%-NN Source Rank"))
        .setDescription(QObject::tr("The ranking given by k-NN, relative to its source node."))
        .setIntValueFn([ranks](EdgeId edgeId) { return static_cast<int>(ranks[edgeId]._source); });

    _graphModel->createAttribute(QObject::tr("%-NN Target Rank"))
        .setDescription(QObject::tr("The ranking given by k-NN, relative to its target node."))
        .setIntValueFn([ranks](EdgeId edgeId) { return static_cast<int>(ranks[edgeId]._target); });

    _graphModel->createAttribute(QObject::tr("%-NN Mean Rank"))
        .setDescription(QObject::tr("The mean ranking given by k-NN."))
        .setFloatValueFn([ranks](EdgeId edgeId) { return ranks[edgeId]._mean; });
}

std::unique_ptr<GraphTransform> PercentNNTransformFactory::create(const GraphTransformConfig&) const
{
    return std::make_unique<PercentNNTransform>(*graphModel());
}