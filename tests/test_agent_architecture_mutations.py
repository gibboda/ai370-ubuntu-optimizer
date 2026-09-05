#!/usr/bin/env python3
"""Negative/mutation tests proving architecture validation fails closed."""

import copy
import json
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
ROLES_PATH = ROOT / "config/agent-roles.json"
COMPATIBILITY_PATH = ROOT / "config/agent-contract-compatibility.json"
FIXTURE_PATH = ROOT / "tests/fixtures/agent-architecture-mutations/v1.json"
EXPECTED_CONTRACTS = {"roles", "escalation", "work_allocation", "credential_capabilities", "mcp", "pr_governance"}


def load(path):
    return json.loads(path.read_text(encoding="utf-8"))


def schema_version(contract):
    if "schema_version" in contract:
        return contract["schema_version"]
    return contract.get("properties", {}).get("schema_version", {}).get("const")


def set_path(document, dotted_path, value):
    current = document
    parts = dotted_path.split(".")
    for part in parts[:-1]:
        current = current[part]
    current[parts[-1]] = value


def validate(roles, compatibility):
    failures = set()
    if roles.get("authority") != "AGENTS.md" or compatibility.get("authority") != "AGENTS.md":
        failures.add("canonical_authority")
    role_map = roles.get("roles", {})
    primary = role_map.get("primary_orchestrator", {})
    if primary.get("provider") != "cursor" or primary.get("count") != 1 or not primary.get("default_task_owner"):
        failures.add("primary_orchestrator")
    if not role_map.get("deterministic_validation", {}).get("before_ai_escalation"):
        failures.add("deterministic_before_escalation")
    reviewer = role_map.get("independent_reviewer", {})
    if not reviewer.get("advisory") or reviewer.get("merge_gate") or reviewer.get("automatic"):
        failures.add("advisory_review")
    authority = role_map.get("merge_authority", {})
    if authority.get("ai_allowed") or not authority.get("human_final"):
        failures.add("human_merge_authority")
    invariants = roles.get("invariants", {})
    if not invariants.get("no_automatic_vendor_chaining"):
        failures.add("no_vendor_chaining")
    if not invariants.get("least_agent_principle"):
        failures.add("least_agent_principle")
    if not invariants.get("duplicate_routine_ai_work_prohibited"):
        failures.add("duplicate_routine_ai_work")
    if not invariants.get("ai_reviews_advisory"):
        failures.add("ai_reviews_advisory")
    if not invariants.get("grok_exclusive_independent_review"):
        failures.add("grok_exclusive_independent_review")
    if set(reviewer.get("providers") or []) != {"grok_build"} or not reviewer.get("exclusive"):
        failures.add("grok_exclusive_independent_review")
    if not invariants.get("cursor_remains_primary"):
        failures.add("cursor_remains_primary")
    if not invariants.get("bugbot_is_cursor_native_autofixer"):
        failures.add("bugbot_is_cursor_native_autofixer")
    if not invariants.get("native_specialist_pass_precedes_final_merge_validation"):
        failures.add("native_specialist_pass_precedes_final_merge_validation")
    overlay_contract = roles.get("overlay_contract", {})
    declared = {entry.get("path") for entry in overlay_contract.get("overlays", [])}
    discovered = set()
    for root in overlay_contract.get("discovery", {}).get("roots", []):
        base = ROOT / root["path"]
        for pattern in root["patterns"]:
            discovered.update(path.relative_to(ROOT).as_posix() for path in base.glob(pattern) if path.is_file())
    exclusions = set(overlay_contract.get("discovery", {}).get("exclusions", []))
    if discovered != declared | exclusions or declared & exclusions:
        failures.add("overlay_completeness")
    contracts = compatibility.get("contracts", {})
    if set(contracts) != EXPECTED_CONTRACTS:
        failures.add("contract_coverage")
    for declaration in contracts.values():
        path = ROOT / declaration.get("path", "")
        if not path.is_file():
            failures.add("contract_coverage")
            continue
        if schema_version(load(path)) != declaration.get("schema_version"):
            failures.add("schema_version_match")
    return failures


def apply_mutation(roles, compatibility, mutation):
    target = roles if mutation["target"] == "roles" else compatibility
    operation = mutation.get("operation", "set")
    if operation == "set":
        set_path(target, mutation["path"], mutation["value"])
    elif operation == "remove_overlay":
        target["overlay_contract"]["overlays"] = [entry for entry in target["overlay_contract"]["overlays"] if entry["path"] != mutation["value"]]
    elif operation == "remove_contract":
        target["contracts"].pop(mutation["value"])
    else:
        raise AssertionError(f"Unknown mutation operation: {operation}")


class AgentArchitectureMutationTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.roles = load(ROLES_PATH)
        cls.compatibility = load(COMPATIBILITY_PATH)
        cls.fixture = load(FIXTURE_PATH)

    def test_canonical_contract_graph_passes_mutation_validator(self):
        self.assertEqual(validate(self.roles, self.compatibility), set())

    def test_fixture_is_versioned_and_has_unique_mutation_ids(self):
        self.assertEqual(self.fixture["schema_version"], 1)
        ids = [mutation["id"] for mutation in self.fixture["mutations"]]
        self.assertGreaterEqual(len(ids), 12)
        self.assertEqual(len(ids), len(set(ids)))

    def test_every_mutation_is_rejected_by_expected_fail_closed_rule(self):
        for mutation in self.fixture["mutations"]:
            roles = copy.deepcopy(self.roles)
            compatibility = copy.deepcopy(self.compatibility)
            apply_mutation(roles, compatibility, mutation)
            failures = validate(roles, compatibility)
            with self.subTest(mutation=mutation["id"]):
                self.assertTrue(failures, "mutated architecture unexpectedly passed")
                self.assertIn(mutation["expected_rule"], failures)

    def test_mutations_cover_critical_architecture_boundaries(self):
        covered = {mutation["expected_rule"] for mutation in self.fixture["mutations"]}
        self.assertEqual(covered, {"canonical_authority", "primary_orchestrator", "deterministic_before_escalation", "advisory_review", "human_merge_authority", "no_vendor_chaining", "least_agent_principle", "duplicate_routine_ai_work", "ai_reviews_advisory", "grok_exclusive_independent_review", "cursor_remains_primary", "bugbot_is_cursor_native_autofixer", "native_specialist_pass_precedes_final_merge_validation", "overlay_completeness", "contract_coverage", "schema_version_match"})


if __name__ == "__main__":
    unittest.main()
