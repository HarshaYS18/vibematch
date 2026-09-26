"""GraphQL query safety checks applied to every allowlisted operation."""

from __future__ import annotations

from dataclasses import dataclass

from graphql import (
    DocumentNode,
    FieldNode,
    FragmentDefinitionNode,
    FragmentSpreadNode,
    InlineFragmentNode,
    OperationDefinitionNode,
)
from graphql.language.ast import SelectionSetNode

from config import settings


@dataclass(frozen=True)
class QueryBudget:
    depth: int
    complexity: int


_FIELD_WEIGHTS = {
    "home": 5,
    "profile": 5,
    "discovery": 5,
    "creatorAdminDashboard": 8,
}


def inspect_query(document: DocumentNode) -> QueryBudget:
    fragments = {
        definition.name.value: definition
        for definition in document.definitions
        if isinstance(definition, FragmentDefinitionNode)
    }
    operations = [
        definition
        for definition in document.definitions
        if isinstance(definition, OperationDefinitionNode)
    ]
    if len(operations) != 1 or operations[0].operation.value != "query":
        raise ValueError("Exactly one read-only query operation is required")

    def walk(
        selection_set: SelectionSetNode,
        depth: int,
        seen: frozenset[str],
    ) -> tuple[int, int]:
        max_depth = depth
        complexity = 0
        for selection in selection_set.selections:
            if isinstance(selection, FieldNode):
                field_name = selection.name.value
                if field_name.startswith("__"):
                    raise ValueError("GraphQL introspection is not available")
                complexity += _FIELD_WEIGHTS.get(field_name, 1)
                max_depth = max(max_depth, depth)
                if selection.selection_set is not None:
                    child_depth, child_complexity = walk(
                        selection.selection_set,
                        depth + 1,
                        seen,
                    )
                    max_depth = max(max_depth, child_depth)
                    complexity += child_complexity
            elif isinstance(selection, InlineFragmentNode):
                child_depth, child_complexity = walk(selection.selection_set, depth, seen)
                max_depth = max(max_depth, child_depth)
                complexity += child_complexity
            elif isinstance(selection, FragmentSpreadNode):
                name = selection.name.value
                if name in seen:
                    raise ValueError("Recursive fragments are not allowed")
                fragment = fragments.get(name)
                if fragment is None:
                    raise ValueError(f"Unknown fragment: {name}")
                child_depth, child_complexity = walk(
                    fragment.selection_set,
                    depth,
                    seen | {name},
                )
                max_depth = max(max_depth, child_depth)
                complexity += child_complexity
        return max_depth, complexity

    depth, complexity = walk(operations[0].selection_set, 1, frozenset())
    if depth > settings.max_depth:
        raise ValueError(f"Query depth {depth} exceeds limit {settings.max_depth}")
    if complexity > settings.max_complexity:
        raise ValueError(
            f"Query complexity {complexity} exceeds limit {settings.max_complexity}"
        )
    return QueryBudget(depth=depth, complexity=complexity)
