#!/usr/bin/env python3
"""S5-M6: repository-owned SuperGrok / xAI pull-request review orchestrator.

This module collects PR context, calls the xAI API directly, schema-validates
the response, applies deterministic governance thresholds, and publishes a
GitHub pull-request review. It is not a Marketplace action wrapper.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
import time
import urllib.error
import urllib.request
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any


OWNER = "S5-M6"
ROOT = Path(__file__).resolve().parents[1]
GROK_DIR = ROOT / ".github" / "grok"
DEFAULT_CONFIG = GROK_DIR / "config.json"
DEFAULT_SCHEMA = GROK_DIR / "schema.json"
DEFAULT_POLICY = GROK_DIR / "policy.md"
DEFAULT_PROMPT = GROK_DIR / "review_prompt.md"

UNTRUSTED_BEGIN = "<<<AI370_UNTRUSTED_BEGIN>>>"
UNTRUSTED_END = "<<<AI370_UNTRUSTED_END>>>"
SEVERITY_RANK = {"critical": 0, "major": 1, "minor": 2, "suggestion": 3}
REVIEW_MACHINERY_PREFIXES = (
    ".github/grok/",
    ".github/workflows/grok-pr-review.yml",
    "scripts/grok_pr_review.py",
    "tests/test_grok_pr_review.py",
)
STAGE1_PREFIXES = (
    "scripts/s1-",
    "scripts/10-detect-hardware.sh",
    "scripts/75-detect-npu.sh",
    "scripts/lib/hardware-detect.sh",
    "scripts/lib/system_profile.py",
    "configs/schemas/s1-",
    "configs/schemas/system-profile.schema.json",
)


class ReviewError(Exception):
    """Fatal review-pipeline error. Do not publish model findings."""


@dataclass
class FileDiff:
    path: str
    status: str
    diff: str
    new_lines: set[int] = field(default_factory=set)
    binary: bool = False


@dataclass
class PreparedReview:
    title: str
    body: str
    base_sha: str
    head_sha: str
    files: list[FileDiff]
    excluded: list[dict[str, str]]
    unreviewed: list[dict[str, str]]
    chunks: list[list[FileDiff]]
    trusted_policy: str
    trusted_prompt: str
    machinery_changed: bool
    stage1_changed: bool
