"""Read-only GraphQL schema for composite FunKey views."""

from __future__ import annotations

from typing import Any

from graphql import (
    GraphQLArgument,
    GraphQLField,
    GraphQLInt,
    GraphQLNonNull,
    GraphQLObjectType,
    GraphQLScalarType,
    GraphQLSchema,
    GraphQLString,
)
from graphql.language import ast

from context import GraphQLRequestContext


def _parse_literal(node: ast.ValueNode, _variables: dict[str, Any] | None = None) -> Any:
    if isinstance(node, ast.StringValueNode):
        return node.value
    if isinstance(node, ast.IntValueNode):
        return int(node.value)
    if isinstance(node, ast.FloatValueNode):
        return float(node.value)
    if isinstance(node, ast.BooleanValueNode):
        return node.value
    if isinstance(node, ast.NullValueNode):
        return None
    if isinstance(node, ast.ListValueNode):
        return [_parse_literal(item) for item in node.values]
    if isinstance(node, ast.ObjectValueNode):
        return {field.name.value: _parse_literal(field.value) for field in node.fields}
    return None


JSON = GraphQLScalarType(
    name="JSON",
    serialize=lambda value: value,
    parse_value=lambda value: value,
    parse_literal=_parse_literal,
)


def _ctx(info) -> GraphQLRequestContext:
    return info.context


async def _home_my_room(root, info):
    del root
    return await _ctx(info).upstream.get_json("core", "/rooms/my-created-room")


async def _home_event_banners(root, info):
    del root
    return await _ctx(info).upstream.get_json(
        "core", "/home-banners", params={"placement": "event"}
    )


async def _home_policy_banners(root, info):
    del root
    return await _ctx(info).upstream.get_json(
        "core", "/home-banners", params={"placement": "policy_rules"}
    )


async def _profile_display(root, info):
    return await _ctx(info).profile_loader.load(root["public_user_id"])


async def _profile_vibes(root, info):
    return await _ctx(info).user_vibes_loader.load(
        (root["public_user_id"], root["vibe_limit"])
    )


async def _profile_follow(root, info):
    return await _ctx(info).upstream.get_json(
        "profile",
        f"/social/public-users/{root['public_user_id']}/follow-status",
    )


async def _discovery_vibes(root, info):
    return await _ctx(info).upstream.get_json(
        "vibes", "/vibes/feed", params={"limit": root["vibe_limit"]}
    )


async def _discovery_rankings(root, info):
    return await _ctx(info).upstream.get_json(
        "core",
        "/rankings/received",
        params={"period": "daily", "limit": root["ranking_limit"]},
    )


async def _discovery_banners(root, info):
    del root
    return await _ctx(info).upstream.get_json(
        "core", "/home-banners", params={"placement": "discovery"}
    )


async def _admin_summary(root, info):
    del root
    return await _ctx(info).upstream.get_json("core", "/admin/control-summary")


async def _admin_audit(root, info):
    del root
    return await _ctx(info).upstream.get_json("core", "/admin/audit-logs")


async def _admin_vibe_reports(root, info):
    return await _ctx(info).upstream.get_json(
        "vibes",
        "/admin/moderation/vibes/reports",
        params={"status": "PENDING", "limit": root["report_limit"]},
    )


HomeComposite = GraphQLObjectType(
    "HomeComposite",
    lambda: {
        "myRoom": GraphQLField(JSON, resolve=_home_my_room),
        "eventBanners": GraphQLField(JSON, resolve=_home_event_banners),
        "policyBanners": GraphQLField(JSON, resolve=_home_policy_banners),
    },
)

ProfileComposite = GraphQLObjectType(
    "ProfileComposite",
    lambda: {
        "profile": GraphQLField(JSON, resolve=_profile_display),
        "vibes": GraphQLField(JSON, resolve=_profile_vibes),
        "followStatus": GraphQLField(JSON, resolve=_profile_follow),
    },
)

DiscoveryComposite = GraphQLObjectType(
    "DiscoveryComposite",
    lambda: {
        "vibes": GraphQLField(JSON, resolve=_discovery_vibes),
        "rankings": GraphQLField(JSON, resolve=_discovery_rankings),
        "banners": GraphQLField(JSON, resolve=_discovery_banners),
    },
)

CreatorAdminDashboard = GraphQLObjectType(
    "CreatorAdminDashboard",
    lambda: {
        "controlSummary": GraphQLField(JSON, resolve=_admin_summary),
        "auditLogs": GraphQLField(JSON, resolve=_admin_audit),
        "vibeReports": GraphQLField(JSON, resolve=_admin_vibe_reports),
    },
)

Query = GraphQLObjectType(
    "Query",
    lambda: {
        "home": GraphQLField(
            GraphQLNonNull(HomeComposite),
            resolve=lambda _root, _info: {},
        ),
        "profile": GraphQLField(
            GraphQLNonNull(ProfileComposite),
            args={
                "publicUserId": GraphQLArgument(GraphQLNonNull(GraphQLString)),
                "vibeLimit": GraphQLArgument(GraphQLInt, default_value=12),
            },
            resolve=lambda _root, _info, publicUserId, vibeLimit=12: {
                "public_user_id": publicUserId,
                "vibe_limit": max(1, min(int(vibeLimit), 30)),
            },
        ),
        "discovery": GraphQLField(
            GraphQLNonNull(DiscoveryComposite),
            args={
                "vibeLimit": GraphQLArgument(GraphQLInt, default_value=20),
                "rankingLimit": GraphQLArgument(GraphQLInt, default_value=20),
            },
            resolve=lambda _root, _info, vibeLimit=20, rankingLimit=20: {
                "vibe_limit": max(1, min(int(vibeLimit), 30)),
                "ranking_limit": max(1, min(int(rankingLimit), 30)),
            },
        ),
        "creatorAdminDashboard": GraphQLField(
            GraphQLNonNull(CreatorAdminDashboard),
            args={"reportLimit": GraphQLArgument(GraphQLInt, default_value=20)},
            resolve=lambda _root, _info, reportLimit=20: {
                "report_limit": max(1, min(int(reportLimit), 50))
            },
        ),
    },
)

schema = GraphQLSchema(query=Query)
