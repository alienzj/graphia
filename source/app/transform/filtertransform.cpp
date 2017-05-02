#include "filtertransform.h"
#include "transformedgraph.h"
#include "attributes/conditionfncreator.h"

#include "graph/graphmodel.h"
#include "graph/componentmanager.h"

#include <algorithm>

#include <QObject>

bool FilterTransform::apply(TransformedGraph& target) const
{
    bool changed = false;

    target.setPhase(QObject::tr("Filtering"));

    auto attributeNames = config().attributeNames();

    if(hasUnknownAttributes(attributeNames, u::toQStringVector(_graphModel->availableAttributes())))
        return false;

    bool ignoreTails =
        std::any_of(attributeNames.begin(), attributeNames.end(),
        [this](const auto& attributeName)
        {
            return _graphModel->attributeByName(attributeName).testFlag(AttributeFlag::IgnoreTails);
        });

    // The elements to be filtered are calculated first and then removed, because
    // removing elements during the filtering could affect the result of filter functions

    switch(_elementType)
    {
    case ElementType::Node:
    {
        auto conditionFn = CreateConditionFnFor::node(*_graphModel, config()._condition);
        if(conditionFn == nullptr)
        {
            addAlert(AlertType::Error, QObject::tr("Invalid condition"));
            return false;
        }

        std::vector<NodeId> removees;

        for(auto nodeId : target.nodeIds())
        {
            if(ignoreTails && target.typeOf(nodeId) == MultiElementType::Tail)
                continue;

            if(u::exclusiveOr(conditionFn(nodeId), _invert))
                removees.push_back(nodeId);
        }

        changed = !removees.empty() || changed;
        for(auto nodeId : removees)
            target.mutableGraph().removeNode(nodeId);
        break;
    }

    case ElementType::Edge:
    {
        auto conditionFn = CreateConditionFnFor::edge(*_graphModel, config()._condition);
        if(conditionFn == nullptr)
        {
            addAlert(AlertType::Error, QObject::tr("Invalid condition"));
            return false;
        }

        std::vector<EdgeId> removees;

        for(auto edgeId : target.edgeIds())
        {
            if(ignoreTails && target.typeOf(edgeId) == MultiElementType::Tail)
                continue;

            if(u::exclusiveOr(conditionFn(edgeId), _invert))
                removees.push_back(edgeId);
        }

        changed = !removees.empty() || changed;
        for(auto edgeId : removees)
            target.mutableGraph().removeEdge(edgeId);
        break;
    }

    case ElementType::Component:
    {
        auto conditionFn = CreateConditionFnFor::component(*_graphModel, config()._condition);
        if(conditionFn == nullptr)
        {
            addAlert(AlertType::Error, QObject::tr("Invalid condition"));
            return false;
        }

        ComponentManager componentManager(target);

        for(auto componentId : componentManager.componentIds())
        {
            auto component = componentManager.componentById(componentId);
            if(u::exclusiveOr(conditionFn(*component), _invert))
            {
                changed = true;
                target.mutableGraph().removeNodes(target.mutableGraph().mergedNodeIdsForNodeIds(component->nodeIds()));
            }
        }
        break;
    }

    default:
        return false;
    }

    return changed;
}

std::unique_ptr<GraphTransform> FilterTransformFactory::create(const GraphTransformConfig&) const
{
    auto filterTransform = std::make_unique<FilterTransform>(elementType(), *graphModel(), _invert);

    return std::move(filterTransform); //FIXME std::move required because of clang bug
}
