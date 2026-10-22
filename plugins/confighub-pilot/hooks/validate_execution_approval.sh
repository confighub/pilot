#!/usr/bin/env bash
#
# PreToolUse hook: classify direct provider effects from raw `cub`/`kubectl`
# commands. In a Pilot-active Claude session, one direct, literal, bounded,
# non-destructive ConfigHub mutation is returned to the host as `ask`: Claude's
# own permission UI decides whether that exact attempt runs. Credential
# disclosures, unbounded organization reads, shell indirection, direct
# Kubernetes writes, destructive operations, and unreviewed executable paths
# remain denied. Host permission authorizes only an attempt; a successful exit
# is not proof until Pilot performs a separate read-only verification and
# records the result.
# Outside Pilot-active sessions this installed hook is completely inert: it
# emits no decision or output and leaves the unrelated host session untouched.
#
# Any allow, ask, or deny outside Pilot-active operation belongs entirely to
# the host and is not inspected or characterized by this hook. This Claude
# hook can force a host decision but cannot prove an approver identity, a
# separate human click, or success of the requested effect. It is a host hook
# boundary, not an OS or
# user-terminal sandbox. Git remains under the host
# assistant's own source-control permissions; Pilot's Git binding applies only
# when a Pilot command performs the push itself. This parser is defense in
# depth, not an authorization boundary: real enforcement requires credentials
# unavailable to the raw assistant shell and provider-side authorization bound
# to the exact approved operation.

set -euo pipefail

# Strict session boundary: an installed Pilot plugin must be inert in every
# Claude session that was not explicitly launched with Pilot active.
# Pilot activation (#764, #1146): active only when PILOT_ACTIVE is exactly 1, or
# when the person using this Claude session typed /confighub-pilot:on. The
# session ID comes from the hook input's top-level JSON field, never from text
# matching, so command text cannot name a different session. A plugin added
# from a marketplace has no installer-supplied PILOT_ROOT, so the switch file
# carries the installed Pilot root that /confighub-pilot:on verified.
if [[ "${PILOT_ACTIVE:-0}" != "1" ]]; then
    pilot_switch_dir="${PILOT_USER_HOME:-${HOME:-}/.pilot}/claude/active-sessions"
    compgen -G "${pilot_switch_dir}/*" >/dev/null 2>&1 || exit 0
    pilot_hook_input="$(cat)"
    pilot_session_state="$(printf '%s' "$pilot_hook_input" | PYTHONDONTWRITEBYTECODE=1 python3 -c 'import json, os, re, sys
try:
    value = json.load(sys.stdin).get("session_id")
except Exception:
    value = None
if not (isinstance(value, str) and re.fullmatch(r"[A-Za-z0-9-]{8,128}", value)):
    raise SystemExit(0)
marker = os.path.join(sys.argv[1], value)
if not os.path.isfile(marker):
    raise SystemExit(0)
root = ""
try:
    recorded = json.load(open(marker, encoding="utf-8")).get("pilot_root")
    if isinstance(recorded, str) and os.path.isfile(os.path.join(recorded, "scripts", "pilot")) and os.path.isfile(os.path.join(recorded, "pilot", "package-manifest.json")):
        root = recorded
except Exception:
    root = ""
print("active:" + root)' "$pilot_switch_dir" 2>/dev/null || true)"
    [[ "$pilot_session_state" == active:* ]] || exit 0
    export PILOT_ACTIVE=1
    pilot_marker_root="${pilot_session_state#active:}"
    if [[ -z "${PILOT_ROOT:-}" && -n "$pilot_marker_root" ]]; then
        export PILOT_ROOT="$pilot_marker_root"
        export PILOT_HOME="$pilot_marker_root"
    fi
    exec 0<<<"$pilot_hook_input"
fi

if ! command -v python3 >/dev/null 2>&1; then
    printf '%s\n' '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"Pilot stopped this command because its own checker cannot run: Python is not available to it. Nothing was attempted. Reinstall Pilot'\''s Claude adapter, then try again. (reason code: APPROVAL_CLASSIFIER_UNAVAILABLE)"}}'
    exit 0
fi

# Bind the executable-name inventory to the hook that was actually invoked.
# This is packaged policy input, not ambient PILOT_ROOT/PILOT_HOME state. The
# Python parser also pins its exact bytes before using any non-prefix alias.
HOOK_DIR="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd -P)"
export PILOT_CUB_ADDON_EXECUTABLE_INVENTORY="$HOOK_DIR/cub_addon_executable_inventory.v1.json"

# Keep the PreToolUse event on fd 3 while the heredoc supplies the Python
# program on stdin. This preserves multiline Bash commands for comment-aware
# clause parsing.
# If the classifier itself fails, say so and ask. A crash must never let a
# command through unseen, and it must not block the session either.
classifier_failed() {
    printf '%s\n' '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"ask","permissionDecisionReason":"Pilot could not check this command because its own checker failed, so it is asking you instead. Review the exact command the host shows, then allow or decline this one attempt. Please report this: it is a Pilot defect. (reason code: APPROVAL_CLASSIFIER_FAILED)"}}'
    exit 0
}
trap 'status=$?; [ "$status" -eq 0 ] || classifier_failed' EXIT

python3 - 3<&0 <<'PY'
from __future__ import annotations

import hashlib
import json
import os
import re
import shlex
import sys
import unicodedata
from pathlib import Path


# The shell dispatcher already returned unless this value is exactly `1`.
# Keep the flag explicit inside the parser so its active-only fail-closed
# branches remain readable and testable.
PILOT_ACTIVE = os.environ.get("PILOT_ACTIVE", "0") == "1"
ADDON_EXECUTABLE_INVENTORY_SHA256 = (
    "774286227909e3669ff24c5b674d00782f6052a3cc952372fb13e48cc5cb55b9"
)
INVALID_ADDON_EXECUTABLE_INVENTORY = "standalone add-on executable inventory invalid"
DYNAMIC_GOVERNED_CUB = "cub <dynamic-governed-route>"
DYNAMIC_LOCAL_KIND_LIFECYCLE = "local-cluster <dynamic-lifecycle>"
PILOT_LOCAL_KIND_LIVE_ROUTE = "pilot local-kind-live-proof --live-kind"
PILOT_ACTIVE_LOCAL_KIND_ROUTES = frozenset({
    "kind create cluster",
    "kind delete cluster",
    "cub cluster up",
    "cub cluster down",
    "cub lk up",
    "cub lk down",
    DYNAMIC_LOCAL_KIND_LIFECYCLE,
    PILOT_LOCAL_KIND_LIVE_ROUTE,
})


UNIT_MUTATION_VERBS = frozenset({
    "apply",
    "approve",
    "cancel",
    "create",
    "data-edit",
    "delete",
    "destroy",
    "edit",
    "import",
    "move",
    "push-upgrade",
    "refresh",
    "set-guard",
    "set-predicates",
    "set-protection",
    "set-target",
    "tag",
    "update",
})
CONFLICT_MUTATION_FLAGS = frozenset({"--apply", "--dismiss"})
GITOPS_MUTATION_VERBS = frozenset({"cleanup", "discover", "import"})
OAUTHCLIENT_MUTATION_VERBS = frozenset({"create", "delete"})
RELEASE_MUTATION_VERBS = frozenset({"delete", "publish", "update", "withdraw"})
# `edit` (cub v0.8.0) opens the whole Space for editing and writes it back.
SPACE_MUTATION_VERBS = frozenset({"create", "delete", "edit", "update"})
# Space leaves reviewed as reads through cub v0.8.1 (confighub/sdk@4e405f89);
# `new-prefix` keeps its own stop. Any other Space leaf is unreviewed.
REVIEWED_SPACE_READ_VERBS = frozenset({"explain", "get", "list", "open"})
# Command/source-reviewed through cub v0.5.7@2417d0ff743ebb82c461c51e13c851a215dee3a0.
# `approve` records an Attestation for one variant Space (docs/engineering/
# OPERATIONAL_INVARIANTS.md, public/cmd/cub/variant_approve.go): the literal one-Space
# form is the interactive lane below (`interactive_cub_scope`); a multi-space
# selection (`--change-order` with `--stage`, or `--where-space`) is not,
# because it can reach Spaces the reviewer never saw named.
VARIANT_MUTATION_VERBS = frozenset({"approve", "create", "promote", "upload"})
REVIEWED_VARIANT_VERBS = VARIANT_MUTATION_VERBS
REVIEWED_K8S_VERBS = frozenset({"collect", "get", "refresh", "source", "types"})
# Unit leaves reviewed as reads through cub v0.6.8 (confighub/sdk@4c8d2fc3), plus the
# older clients' livedata/livestate/bridgestate reads. blame and
# the conflicts write flags keep their own stops below. Any other leaf is either a
# reviewed write in UNIT_MUTATION_VERBS or unreviewed: v0.6.8 renamed `unit edit` to
# `unit data-edit` (#5547), and a renamed write must not inherit read-only status.
REVIEWED_UNIT_READ_VERBS = frozenset({
    "blame",
    "bridgestate",
    "conflicts",
    "data",
    "diff",
    "explain",
    "get",
    "list",
    "livedata",
    "livestate",
    "mutation-sources",
    "open",
    "tree",
})
KUBECTL_MUTATION_VERBS = frozenset({
    "annotate",
    "apply",
    "autoscale",
    "cordon",
    "cp",
    "create",
    "delete",
    "debug",
    "drain",
    "edit",
    "exec",
    "expose",
    "label",
    "patch",
    "replace",
    "run",
    "scale",
    "set",
    "taint",
    "uncordon",
})
KUBECTL_GLOBAL_VALUE_FLAGS = frozenset({
    "--as",
    "--as-group",
    "--as-uid",
    "--as-user-extra",
    "--cache-dir",
    "--certificate-authority",
    "--client-certificate",
    "--client-key",
    "--cluster",
    "--context",
    "--kubeconfig",
    "--kuberc",
    "--log-flush-frequency",
    "--namespace",
    "--password",
    "--profile",
    "--profile-output",
    "--request-timeout",
    "--server",
    "--tls-server-name",
    "--token",
    "--user",
    "--username",
    "--v",
    "--vmodule",
    "-n",
    "-s",
    "-v",
})
KUBECTL_GET_VALUE_FLAGS = KUBECTL_GLOBAL_VALUE_FLAGS | frozenset({
    "--chunk-size",
    "--field-selector",
    "--filename",
    "--kustomize",
    "--label-columns",
    "--output",
    "--raw",
    "--selector",
    "--sort-by",
    "--subresource",
    "--template",
    "-L",
    "-f",
    "-k",
    "-l",
    "-o",
})
KUBECTL_DESCRIBE_VALUE_FLAGS = KUBECTL_GLOBAL_VALUE_FLAGS | frozenset({
    "--chunk-size",
    "--filename",
    "--kustomize",
    "--selector",
    "-f",
    "-k",
    "-l",
})
REVIEWED_KUBECTL_NOUNS = frozenset({
    "annotate",
    "api-resources",
    "api-versions",
    "apply",
    "attach",
    "auth",
    "autoscale",
    "certificate",
    "cluster-info",
    "completion",
    "config",
    "cordon",
    "cp",
    "create",
    "debug",
    "delete",
    "describe",
    "diff",
    "drain",
    "edit",
    "events",
    "exec",
    "explain",
    "expose",
    "get",
    "help",
    "kuberc",
    "kustomize",
    "label",
    "logs",
    "options",
    "patch",
    "plugin",
    "port-forward",
    "proxy",
    "replace",
    "rollout",
    "run",
    "scale",
    "set",
    "taint",
    "top",
    "uncordon",
    "version",
    "wait",
})
KIND_GLOBAL_VALUE_FLAGS = frozenset({"--loglevel", "--verbosity", "-v"})
CUB_VALUE_FLAGS = frozenset({"--context", "--output", "--space", "-o"})
CUB_COMMAND_BOOLEAN_FLAGS = frozenset({"--debug", "--help", "-h"})
CUB_RUN_VALUE_FLAGS = CUB_VALUE_FLAGS | frozenset({
    "--change-desc",
    "--changeset",
    "--clearance",
    "--executor-space",
    "--filter",
    "--invocation",
    "--livestate-type",
    "--other-data-source",
    "--output-file",
    "--resource-type",
    "--revision",
    "--show",
    "--timeout",
    "--toolchain",
    "--trigger",
    "--unit",
    "--where",
    "--where-data",
    "--where-resource",
    "--worker",
    "-O",
})
KEY_AUTHORITY_NOUNS = frozenset({"user", "worker"})
KEY_AUTHORITY_OPERATIONS = frozenset({"add", "delete", "list"})
KEY_AUTHORITY_VALUE_FLAGS = CUB_VALUE_FLAGS | frozenset({"--user", "--worker"})
UNREVIEWED_RELEASE_BOUNDARY_PREFIXES = (
    "ChangeSet:",
    "Before:ChangeSet:",
    "ChangeOrder:",
    "Before:ChangeOrder:",
)
READ_ONLY_CUB_RUN_FUNCTIONS = frozenset({
    "cel-validate",
    "compute-mutations",
    "get-annotation",
    "get-attribute",
    "get-bool-path",
    "get-cel",
    "get-container-flag",
    "get-container-image",
    "get-container-image-reference",
    "get-container-name",
    "get-container-repository-uri",
    "get-details",
    "get-env-var",
    "get-hostname",
    "get-hostname-domain",
    "get-hostname-subdomain",
    "get-image",
    "get-image-reference",
    "get-image-uri",
    "get-int-path",
    "get-label",
    "get-name",
    "get-namespace",
    "get-needed",
    "get-needed-namespaces",
    "get-path",
    "get-paths",
    "get-placeholder-mutations",
    "get-placeholders",
    "get-provided",
    "get-references",
    "get-references-of-type",
    "get-replicas",
    "get-resources",
    "get-resources-of-type",
    "get-starlark",
    "get-string-path",
    "get-workload-labels",
    "get-yq",
    "is-approved",
    "no-placeholders",
    "render-configmap",
    "validate",
    "vet-approvedby",
    "vet-cel",
    "vet-celexpr",
    "vet-disruption",
    "vet-format",
    "vet-images",
    "vet-immutable",
    "vet-jsonschema",
    "vet-merge-keys",
    "vet-no-merge-conflicts",
    "vet-placeholders",
    "vet-schemas",
    "vet-starlark",
    "vet-values",
    "where-filter",
    "yq",
})
AUTH_SENSITIVE_VERBS = frozenset({
    "browser-session",
    "get-token",
    "login",
    "switch",
    "test-login",
})
# "set" is kept although cub v0.5.2 removed the command. An older cub still
# has it, and dropping it here would turn a deny into an allow for those
# clients. A verb that no longer exists costs nothing to keep denying.
CONTEXT_MUTATION_VERBS = frozenset({"create", "delete", "rename", "set", "set-current", "use"})
PLUGIN_LIFECYCLE_VERBS = frozenset({"install", "uninstall", "upgrade"})
WORKER_CREDENTIAL_VERBS = frozenset({"get-envs", "get-secret"})
BRIDGE_WORKER_EXPANDING_READ_NOUNS = frozenset({
    "invocation",
    "target",
    "trigger",
    "unit",
    "worker",
})
REMOTE_SPACE_LIST_NOUNS = frozenset({
    "attribute",
    "changeorder",
    "changeset",
    "filter",
    "function",
    "invocation",
    "link",
    "mutation",
    "release",
    "resource",
    "revision",
    "tag",
    "target",
    "trigger",
    "unit",
    "unit-action",
    "unit-event",
    "view",
    "worker",
})
UNBOUNDED_ORGANIZATION_LIST_NOUNS = frozenset({
    "component",
    "organization",
    "organization-member",
    "space",
    "user",
})
REVIEWED_CORE_CUB_NOUNS = frozenset({
    "attestation",
    "attribute",
    "auth",
    "changeorder",
    "changeset",
    "cluster",
    "completion",
    "component",
    "context",
    "filter",
    "function",
    "help",
    "info",
    "invocation",
    "k8s",
    "link",
    "mutation",
    "oauthclient",
    "organization",
    "organization-member",
    "plugin",
    "release",
    "resource",
    "revision",
    "run",
    "space",
    "tag",
    "target",
    "trigger",
    "unit",
    "unit-action",
    "unit-event",
    "upgrade",
    "user",
    "variant",
    "version",
    "view",
    "worker",
})
REVIEWED_LOCAL_CUB_FUNCTIONS = frozenset({
    "cel-validate",
    "compute-mutations",
    "delete-path",
    "delete-resource",
    "ensure-context",
    "ensure-namespaces",
    "generate-kubecontext",
    "get-annotation",
    "get-attribute",
    "get-bool-path",
    "get-cel",
    "get-container-flag",
    "get-container-image",
    "get-container-image-reference",
    "get-container-name",
    "get-container-repository-uri",
    "get-details",
    "get-env-var",
    "get-hostname",
    "get-hostname-domain",
    "get-hostname-subdomain",
    "get-image",
    "get-image-reference",
    "get-image-uri",
    "get-int-path",
    "get-label",
    "get-name",
    "get-namespace",
    "get-needed",
    "get-needed-namespaces",
    "get-path",
    "get-paths",
    "get-placeholder-mutations",
    "get-placeholders",
    "get-provided",
    "get-references",
    "get-references-of-type",
    "get-replicas",
    "get-resources",
    "get-resources-of-type",
    "get-starlark",
    "get-string-path",
    "get-workload-labels",
    "get-yq",
    "is-approved",
    "no-placeholders",
    "patch-mutations",
    "prune-configmaps",
    "render-configmap",
    "replicate",
    "reset",
    "search-replace",
    "select-where-resource",
    "set-annotation",
    "set-attributes",
    "set-automount-service-account-token-false",
    "set-bool-path",
    "set-cel",
    "set-container-flag",
    "set-container-image",
    "set-container-image-reference",
    "set-container-port",
    "set-container-probe-defaults",
    "set-container-repository-uri",
    "set-container-resources",
    "set-container-resources-defaults",
    "set-container-volume-mount-path",
    "set-default-names",
    "set-env",
    "set-env-var",
    "set-hash",
    "set-hostname",
    "set-hostname-domain",
    "set-hostname-subdomain",
    "set-image",
    "set-image-reference",
    "set-image-reference-by-uri",
    "set-image-registry-by-registry",
    "set-image-uri",
    "set-int-path",
    "set-label",
    "set-name",
    "set-namespace",
    "set-path",
    "set-path-comment",
    "set-pod-defaults",
    "set-pod-security-defaults",
    "set-protection",
    "set-references-of-type",
    "set-replicas",
    "set-starlark",
    "set-string-path",
    "set-template",
    "set-workload-labels",
    "set-yq",
    "upsert-resource",
    "validate",
    "vet-approvedby",
    "vet-cel",
    "vet-celexpr",
    "vet-disruption",
    "vet-format",
    "vet-images",
    "vet-immutable",
    "vet-jsonschema",
    "vet-merge-keys",
    "vet-no-merge-conflicts",
    "vet-placeholders",
    "vet-schemas",
    "vet-starlark",
    "vet-values",
    "where-filter",
    "yq",
    "yq-i",
})
# v0.4.1's interactive lane is intentionally smaller than Cub's mutating
# function catalog. These four built-ins have simple literal argument shapes
# and cover ordinary replica, image, and namespace changes. Code-bearing,
# selector-bearing, resource-upsert, query, and arbitrary path functions stay
# on separately reviewed routes.
INTERACTIVE_MUTATING_FUNCTIONS = frozenset({
    "set-container-image",
    "set-image",
    "set-namespace",
    "set-replicas",
})
# Cobra/pflag delegates explicit boolean values to Go's strconv.ParseBool.
# Keep this exact: accepting friendly spellings such as "yes" or "off" would
# classify argv that the reviewed client rejects rather than executes.
FALSE_FLAG_VALUES = frozenset({"false", "f", "0"})
TRUE_FLAG_VALUES = frozenset({"true", "t", "1"})
CUB_ENTITY_MUTATION_VERBS = frozenset({
    "add",
    "apply",
    "approve",
    "cancel",
    "cleanup",
    "collect",
    "create",
    "delete",
    "destroy",
    "discover",
    "data-edit",
    "edit",
    "import",
    "install",
    "move",
    "promote",
    "publish",
    "refresh",
    "reject",
    "remove",
    "restore",
    "revoke",
    "run",
    "set",
    "stop",
    "tag",
    "unapprove",
    "uninstall",
    "update",
    "upgrade",
    "upload",
    "withdraw",
})
# `component` joined on 2026-10-04: its create, update, delete and edit leaves
# (present since cub v0.5.7) passed with no decision, including
# `component update --change-workflow-required=false`, which removes a
# Component's required ChangeWorkflow.
CUB_GENERIC_ENTITY_NOUNS = frozenset({
    "attestation",
    "attribute",
    "changeorder",
    "changeset",
    "component",
    "filter",
    "invocation",
    "link",
    "mutation",
    "organization",
    "organization-member",
    "tag",
    "target",
    "trigger",
    "view",
    "worker",
})
# Generic-entity leaves reviewed as reads through cub v0.8.1
# (confighub/sdk@4e405f89), plus the older clients' `worker get-image` and
# `worker logs`, which the approval-gate effect review classifies as reads. A leaf that is neither one of these nor a reviewed
# write is unreviewed and stops: `move` and `edit` reached entities one release
# at a time and inherited read-only status because nothing listed them.
REVIEWED_GENERIC_ENTITY_READ_VERBS = frozenset({
    "explain",
    "get",
    "get-image",
    "list",
    "list-function",
    "list-status",
    "logs",
    "open",
})
SHELL_EXECUTABLES = frozenset({"bash", "dash", "sh", "zsh"})
VISIBLE_PROVIDER_EXECUTABLES = frozenset({
    "cub",
    "kind",
    "kubectl",
    "pilot",
    "pilot-local-kind-live-proof",
})
# These programs launch a command supplied in their argv (and, for xargs/find,
# can additionally splice runtime data into it). They are not transparent shell
# syntax, so a visible provider payload must not fall through as an ordinary
# invocation merely because the wrapper owns argv[0].
UNREVIEWED_EXECUTION_WRAPPERS = frozenset({
    "chrt",
    "doas",
    "find",
    "ionice",
    "nice",
    "nohup",
    "parallel",
    "script",
    "setsid",
    "stdbuf",
    "sudo",
    "timeout",
    "time",
    "watch",
    "xargs",
})
XARGS_REQUIRED_VALUE_FLAGS = frozenset({
    "--arg-file",
    "--delimiter",
    "--max-args",
    "--max-chars",
    "--max-procs",
    "--process-slot-var",
    "-E",
    "-I",
    "-J",
    "-L",
    "-P",
    "-R",
    "-S",
    "-a",
    "-d",
    "-n",
    "-s",
})
XARGS_OPTIONAL_VALUE_FLAGS = frozenset({
    "--eof",
    "--max-lines",
    "--replace",
    "-e",
    "-l",
})
ENV_VALUE_FLAGS = frozenset({"-C", "--chdir", "-P", "-u", "--unset"})
ENV_SPLIT_FLAGS = frozenset({"-S", "--split-string"})
ASSIGNMENT = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*=")
EXPANSION_SENTINEL = "\ue000"
REDIRECTION_SENTINEL = "\ue001"


def strict_json_object(raw: bytes) -> dict:
    """Decode one object while rejecting duplicate keys at every depth."""

    def pairs_object(pairs: list[tuple[str, object]]) -> dict:
        result: dict = {}
        for key, value in pairs:
            if key in result:
                raise ValueError("duplicate inventory key")
            result[key] = value
        return result

    decoded = json.loads(raw, object_pairs_hook=pairs_object)
    if not isinstance(decoded, dict):
        raise ValueError("inventory root must be an object")
    return decoded


def load_addon_executable_inventory() -> tuple[frozenset[str], bool]:
    """Load the exact adjacent add-on basename policy without trusting cwd."""

    path_value = os.environ.get("PILOT_CUB_ADDON_EXECUTABLE_INVENTORY", "")
    try:
        raw = Path(path_value).read_bytes()
        if hashlib.sha256(raw).hexdigest() != ADDON_EXECUTABLE_INVENTORY_SHA256:
            raise ValueError("inventory digest mismatch")
        inventory = strict_json_object(raw)
        if (
            inventory.get("schema")
            != "confighub-pilot.cub-addon-executable-inventory.v1"
            or inventory.get("status") != "reviewed-static-hook-policy"
            or inventory.get("default_disposition") != "ASK"
            or inventory.get("basename_prefixes") != ["cub-"]
        ):
            raise ValueError("inventory control fields mismatch")
        assertions = inventory.get("source_assertions")
        prefixed = inventory.get("reviewed_prefixed_executables")
        aliases = inventory.get("reviewed_nonprefixed_aliases")
        if not isinstance(assertions, list) or len(assertions) != 3:
            raise ValueError("inventory source assertions missing")
        if not isinstance(prefixed, list) or not isinstance(aliases, list):
            raise ValueError("inventory executable lists missing")
        for name in [*prefixed, *aliases]:
            if (
                not isinstance(name, str)
                or re.fullmatch(r"[a-z0-9][a-z0-9-]*", name) is None
                or "/" in name
            ):
                raise ValueError("invalid inventory executable")
        if any(not name.startswith("cub-") for name in prefixed):
            raise ValueError("reviewed prefixed executable is outside cub- perimeter")
        if any(name.startswith("cub-") for name in aliases):
            raise ValueError("non-prefixed alias duplicates cub- perimeter")
        basenames = [*prefixed, *aliases]
        if len(basenames) != len(set(basenames)):
            raise ValueError("duplicate inventory executable")
        return frozenset(basenames), True
    except (OSError, UnicodeDecodeError, ValueError, TypeError, json.JSONDecodeError):
        # The `cub-` prefix remains fail-closed even if the packaged inventory
        # is damaged. The current reviewed inventory contains no non-prefixed
        # alias, so no fail-open alias is hidden by this bounded fallback.
        return frozenset(), False


REVIEWED_STANDALONE_CUB_ADDON_BASENAMES, ADDON_EXECUTABLE_INVENTORY_VALID = (
    load_addon_executable_inventory()
)


def heredoc_delimiter(command: str, start: int) -> tuple[str, bool, bool]:
    """Read one heredoc delimiter and whether its body performs expansion."""
    index = start
    strip_tabs = index < len(command) and command[index] == "-"
    if strip_tabs:
        index += 1
    while index < len(command) and command[index] in " \t":
        index += 1
    if index >= len(command) or command[index] in "\n;|&":
        return "", strip_tabs, False
    if command[index] in {"'", '"'}:
        quote = command[index]
        index += 1
        value: list[str] = []
        while index < len(command) and command[index] != quote:
            value.append(command[index])
            index += 1
        return "".join(value), strip_tabs, False
    value = []
    expands = True
    while index < len(command) and not command[index].isspace() and command[index] not in ";|&":
        if command[index] == "\\" and index + 1 < len(command):
            # Any quoted delimiter character disables parameter, command and
            # arithmetic expansion in the complete heredoc body.
            expands = False
            index += 1
        value.append(command[index])
        index += 1
    return "".join(value), strip_tabs, expands


def split_shell_clauses(command: str) -> list[str]:
    """Split simple Bash clauses without treating quoted text as commands."""
    clauses: list[str] = []
    current: list[str] = []
    pending_heredocs: list[tuple[str, bool]] = []
    active_heredocs: list[tuple[str, bool]] = []
    quote = ""
    in_comment = False
    index = 0

    def flush() -> None:
        value = "".join(current).strip()
        if value:
            clauses.append(value)
        current.clear()

    while index < len(command):
        if active_heredocs:
            line_end = command.find("\n", index)
            if line_end < 0:
                line_end = len(command)
            line = command[index:line_end]
            delimiter, strip_tabs = active_heredocs[0]
            if (line.lstrip("\t") if strip_tabs else line) == delimiter:
                active_heredocs.pop(0)
            index = line_end + 1
            continue
        char = command[index]
        if in_comment:
            if char == "\n":
                flush()
                in_comment = False
                if pending_heredocs:
                    active_heredocs.extend(pending_heredocs)
                    pending_heredocs.clear()
            index += 1
            continue
        if quote:
            current.append(char)
            if quote == '"' and char == "\\" and index + 1 < len(command):
                current.append(command[index + 1])
                index += 2
                continue
            if char == quote:
                quote = ""
            index += 1
            continue
        if char in {"'", '"'}:
            quote = char
            current.append(char)
        elif char == "\\" and index + 1 < len(command):
            current.extend((char, command[index + 1]))
            index += 2
            continue
        elif char == "#" and (not current or current[-1].isspace() or current[-1] in ";|&"):
            in_comment = True
        elif char == "<" and index + 1 < len(command) and command[index + 1] == "<":
            delimiter, strip_tabs, _ = heredoc_delimiter(command, index + 2)
            if delimiter:
                pending_heredocs.append((delimiter, strip_tabs))
            current.append(char)
        elif char == "&" and (
            (index + 1 < len(command) and command[index + 1] == ">")
            or (current and current[-1] in {"<", ">"})
        ):
            # `&>`, `&>>`, `<&`, and `>&` are redirections, not command-list
            # separators. Preserve them for the redirection-aware argv pass.
            current.append(char)
        elif char == "|" and current and current[-1] == ">":
            # `>|` is noclobber-overriding output redirection.
            current.append(char)
        elif char in {"\n", ";", "|", "&"}:
            flush()
            if char == "\n" and pending_heredocs:
                active_heredocs.extend(pending_heredocs)
                pending_heredocs.clear()
            if char in {"|", "&"} and index + 1 < len(command) and command[index + 1] == char:
                index += 1
        else:
            current.append(char)
        index += 1
    flush()
    return clauses


def tokens_for(clause: str) -> list[str]:
    try:
        return shlex.split(clause, comments=True, posix=True)
    except ValueError:
        return []


def redirection_marked_source(clause: str) -> str:
    """Mark syntactic shell redirections without touching quoted data."""
    if REDIRECTION_SENTINEL in clause:
        clause = clause.replace(
            REDIRECTION_SENTINEL,
            "$" + REDIRECTION_SENTINEL,
        )
    marked: list[str] = []
    quote = ""
    index = 0
    while index < len(clause):
        char = clause[index]
        if quote:
            marked.append(char)
            if quote == '"' and char == "\\" and index + 1 < len(clause):
                marked.append(clause[index + 1])
                index += 2
                continue
            if char == quote:
                quote = ""
            index += 1
            continue
        if char in {"'", '"'}:
            quote = char
            marked.append(char)
            index += 1
            continue
        if char == "\\" and index + 1 < len(clause):
            marked.extend((char, clause[index + 1]))
            index += 2
            continue
        redirect = char in {"<", ">"} or (
            char == "&"
            and index + 1 < len(clause)
            and clause[index + 1] == ">"
        )
        if not redirect:
            marked.append(char)
            index += 1
            continue

        # An immediately adjacent decimal fd (or Bash `{var}` fd) belongs to
        # the operator. Remove only a complete current shell-word prefix, never
        # a suffix such as the `2` in `name2>file`.
        prefix_start = len(marked)
        while prefix_start and not marked[prefix_start - 1].isspace():
            prefix_start -= 1
        prefix = "".join(marked[prefix_start:])
        if re.fullmatch(r"(?:[0-9]+|\{[A-Za-z_][A-Za-z0-9_]*\})", prefix):
            del marked[prefix_start:]

        if char == "&":
            index += 2
            if index < len(clause) and clause[index] == ">":
                index += 1
        else:
            index += 1
            if index < len(clause) and clause[index] == char:
                index += 1
                if char == "<" and index < len(clause) and clause[index] == "-":
                    index += 1
                elif char == "<" and index < len(clause) and clause[index] == "<":
                    index += 1
            elif index < len(clause) and clause[index] in {"&", ">", "|"}:
                index += 1
        marked.extend((" ", REDIRECTION_SENTINEL, " "))
    return "".join(marked)


def expansion_masked_source(clause: str) -> str:
    """Mark expansions Bash will evaluate while preserving shell word shape.

    ``shlex`` deliberately removes quote syntax. That is useful for argv
    classification but previously made a single-quoted dollar indistinguishable
    from ``"$NAME"``. Mask only expansion-active dollars/backticks before a
    second shlex pass, so literal single-quoted and backslash-escaped bytes stay
    ordinary argument data.
    """
    if EXPANSION_SENTINEL in clause:
        # The sentinel is not valid review input. Conservatively make the
        # resulting word expansion-bearing instead of risking an ambiguity.
        clause = clause.replace(EXPANSION_SENTINEL, "$" + EXPANSION_SENTINEL)
    masked: list[str] = []
    quote = ""
    index = 0
    while index < len(clause):
        char = clause[index]
        if quote == "'":
            masked.append(char)
            if char == "'":
                quote = ""
            index += 1
            continue
        if quote == '"':
            if char == "\\" and index + 1 < len(clause):
                masked.extend((char, clause[index + 1]))
                index += 2
                continue
            if char == '"':
                quote = ""
                masked.append(char)
            elif char in {"$", "`"}:
                masked.append(EXPANSION_SENTINEL)
            else:
                masked.append(char)
            index += 1
            continue
        if char == "\\" and index + 1 < len(clause):
            masked.extend((char, clause[index + 1]))
            index += 2
            continue
        if char == "'":
            quote = "'"
            masked.append(char)
        elif char == '"':
            quote = '"'
            masked.append(char)
        elif char in {"$", "`"}:
            # Bash reparses ANSI-C and locale-quoted words before execution,
            # while Python's lightweight shlex does not. Mark the prefix as
            # unresolved rather than misclassifying `$'kubectl'` as harmless.
            masked.append(EXPANSION_SENTINEL)
        elif char in {"*", "?"}:
            # Pathname expansion can resolve argv[0] or any protected control
            # argument after review. Quoted and escaped metacharacters were
            # handled above and remain literal.
            masked.append(EXPANSION_SENTINEL)
        elif char == "[":
            token_end = index + 1
            while token_end < len(clause) and not clause[token_end].isspace():
                if clause[token_end] == "]":
                    break
                token_end += 1
            masked.append(
                EXPANSION_SENTINEL
                if token_end < len(clause) and clause[token_end] == "]"
                else char
            )
        elif char == "{":
            token_end = index + 1
            while token_end < len(clause) and not clause[token_end].isspace():
                if clause[token_end] == "}":
                    break
                token_end += 1
            body = clause[index + 1 : token_end]
            masked.append(
                EXPANSION_SENTINEL
                if token_end < len(clause)
                and clause[token_end] == "}"
                and ("," in body or ".." in body)
                else char
            )
        else:
            masked.append(char)
        index += 1
    return "".join(masked)


def remove_shell_line_continuations(clause: str) -> str:
    """Apply Bash's pre-tokenization backslash-newline removal.

    Continuations are removed unquoted and inside double quotes, but remain
    literal inside single quotes. Keeping them lets `ku\\\nbectl` evade an
    executable-name classifier even though Bash executes `kubectl`.
    """
    normalized: list[str] = []
    quote = ""
    index = 0
    while index < len(clause):
        char = clause[index]
        if quote == "'":
            normalized.append(char)
            if char == "'":
                quote = ""
            index += 1
            continue
        if char == "\\" and index + 1 < len(clause) and clause[index + 1] == "\n":
            index += 2
            continue
        normalized.append(char)
        if char in {"'", '"'}:
            if not quote:
                quote = char
            elif quote == char:
                quote = ""
        index += 1
    return "".join(normalized)


def tokens_with_expansion(clause: str) -> tuple[list[str], list[bool]]:
    """Return shell words plus whether each word contains active expansion."""
    clause = remove_shell_line_continuations(clause)
    marked = redirection_marked_source(clause)
    tokens = tokens_for(marked)
    if not tokens:
        return [], []
    masked = tokens_for(expansion_masked_source(marked))
    if len(masked) != len(tokens):
        # A shape mismatch means the lightweight lexer cannot preserve enough
        # provenance to grant a literal-only exemption.
        return tokens, [True] * len(tokens)
    flags = [EXPANSION_SENTINEL in token for token in masked]
    command_tokens: list[str] = []
    command_flags: list[bool] = []
    index = 0
    while index < len(tokens):
        if tokens[index] == REDIRECTION_SENTINEL:
            # Every shell redirection has one following word (filename, fd,
            # here-string, or heredoc delimiter). Invalid missing-target syntax
            # cannot execute the provider and therefore has no payload to keep.
            index += 2
            continue
        command_tokens.append(tokens[index])
        command_flags.append(flags[index])
        index += 1
    return command_tokens, command_flags


def basename(token: str) -> str:
    return token.rsplit("/", 1)[-1]


SCOUT_STANDALONE_EXECUTABLE = "cub-scout"
SCOUT_PLUGIN_NOUN = "scout"


def protected_standalone_cub_addon(executable: str) -> str:
    """Fail closed for direct Cub add-on executables visible by basename.

    Every ``cub-`` basename is in scope even when it has never been reviewed.
    The adjacent digest-pinned inventory additionally supplies exact known
    basenames, including any future reviewed non-prefixed alias. This is name
    classification only: it neither authenticates executable bytes nor finds a
    literal binary that was renamed outside both sets.
    """

    if executable == SCOUT_STANDALONE_EXECUTABLE:
        # Scout has its own hook, validate_cub_scout.sh: a reviewed read runs,
        # a write asks, a credential flag is stopped. This hook leaves Scout
        # to it (operator decisions 2026-09-23 and 2026-10-11).
        return ""
    if executable in REVIEWED_STANDALONE_CUB_ADDON_BASENAMES:
        return f"{executable} reviewed-name-standalone-add-on"
    if executable.startswith("cub-"):
        return "cub-* unassessed-standalone-add-on"
    return ""


def command_substitutions(command: str) -> list[str]:
    """Return executable `$()` and backtick command-substitution bodies."""
    substitutions: list[str] = []

    def backtick_body(start: int) -> tuple[str, int]:
        index = start + 1
        while index < len(command):
            if command[index] == "\\" and index + 1 < len(command):
                index += 2
                continue
            if command[index] == "`":
                return command[start + 1 : index], index
            index += 1
        return "", len(command)

    def dollar_body(start: int) -> tuple[str, int]:
        index = start + 2
        depth = 1
        quote = ""
        in_comment = False
        while index < len(command):
            char = command[index]
            if in_comment:
                if char == "\n":
                    in_comment = False
                index += 1
                continue
            if quote:
                if quote == '"' and char == "\\" and index + 1 < len(command):
                    index += 2
                    continue
                if quote == '"' and char == "$" and index + 1 < len(command) and command[index + 1] == "(":
                    _, nested_end = dollar_body(index)
                    index = nested_end + 1
                    continue
                if quote == '"' and char == "`":
                    _, nested_end = backtick_body(index)
                    index = nested_end + 1
                    continue
                if char == quote:
                    quote = ""
                index += 1
                continue
            if char in {"'", '"'}:
                quote = char
            elif char == "\\" and index + 1 < len(command):
                index += 2
                continue
            elif char == "#" and (index == start + 2 or command[index - 1].isspace()):
                in_comment = True
            elif char == "$" and index + 1 < len(command) and command[index + 1] == "(":
                _, nested_end = dollar_body(index)
                index = nested_end + 1
                continue
            elif char == "`":
                _, nested_end = backtick_body(index)
                index = nested_end + 1
                continue
            elif char == "(":
                depth += 1
            elif char == ")":
                depth -= 1
                if depth == 0:
                    return command[start + 2 : index], index
            index += 1
        return "", len(command)

    index = 0
    quote = ""
    in_comment = False
    while index < len(command):
        char = command[index]
        if in_comment:
            if char == "\n":
                in_comment = False
            index += 1
            continue
        if quote:
            if quote == '"' and char == "\\" and index + 1 < len(command):
                index += 2
                continue
            if quote == '"' and char == "$" and index + 1 < len(command) and command[index + 1] == "(":
                body, end = dollar_body(index)
                if end < len(command):
                    substitutions.append(body)
                index = end + 1
                continue
            if quote == '"' and char == "`":
                body, end = backtick_body(index)
                if end < len(command):
                    substitutions.append(body)
                index = end + 1
                continue
            if char == quote:
                quote = ""
            index += 1
            continue
        if char in {"'", '"'}:
            quote = char
        elif char == "\\" and index + 1 < len(command):
            index += 2
            continue
        elif char == "#" and (index == 0 or command[index - 1].isspace() or command[index - 1] in ";|&"):
            in_comment = True
        elif char == "$" and index + 1 < len(command) and command[index + 1] == "(":
            body, end = dollar_body(index)
            if end < len(command):
                substitutions.append(body)
            index = end + 1
            continue
        elif char == "`":
            body, end = backtick_body(index)
            if end < len(command):
                substitutions.append(body)
            index = end + 1
            continue
        index += 1
    return substitutions


def process_substitutions(command: str) -> list[str]:
    """Return executable Bash `<(...)` and `>(...)` bodies."""
    substitutions: list[str] = []

    def body(start: int) -> tuple[str, int]:
        index = start + 2
        depth = 1
        quote = ""
        while index < len(command):
            char = command[index]
            if quote:
                if quote == '"' and char == "\\" and index + 1 < len(command):
                    index += 2
                    continue
                if char == quote:
                    quote = ""
                index += 1
                continue
            if char in {"'", '"'}:
                quote = char
            elif char == "\\" and index + 1 < len(command):
                index += 2
                continue
            elif char == "(":
                depth += 1
            elif char == ")":
                depth -= 1
                if depth == 0:
                    return command[start + 2 : index], index
            index += 1
        return "", len(command)

    index = 0
    quote = ""
    in_comment = False
    while index < len(command):
        char = command[index]
        if in_comment:
            if char == "\n":
                in_comment = False
            index += 1
            continue
        if quote:
            if quote == '"' and char == "\\" and index + 1 < len(command):
                index += 2
                continue
            if char == quote:
                quote = ""
            index += 1
            continue
        if char in {"'", '"'}:
            quote = char
        elif char == "\\" and index + 1 < len(command):
            index += 2
            continue
        elif char == "#" and (index == 0 or command[index - 1].isspace() or command[index - 1] in ";|&"):
            in_comment = True
        elif char in {"<", ">"} and index + 1 < len(command) and command[index + 1] == "(":
            value, end = body(index)
            if end < len(command):
                substitutions.append(value)
            index = end + 1
            continue
        index += 1
    return substitutions


def expanded_heredoc_bodies(command: str) -> list[str]:
    """Return only heredoc bodies in which Bash performs substitutions."""
    bodies: list[str] = []
    pending: list[tuple[str, bool, bool]] = []
    active: tuple[str, bool, bool] | None = None
    active_lines: list[str] = []

    for line in command.splitlines():
        if active is not None:
            delimiter, strip_tabs, expands = active
            if (line.lstrip("\t") if strip_tabs else line) == delimiter:
                if expands:
                    bodies.append("\n".join(active_lines))
                active_lines = []
                active = pending.pop(0) if pending else None
            else:
                active_lines.append(line)
            continue

        quote = ""
        in_comment = False
        index = 0
        while index < len(line):
            char = line[index]
            if in_comment:
                break
            if quote:
                if quote == '"' and char == "\\" and index + 1 < len(line):
                    index += 2
                    continue
                if char == quote:
                    quote = ""
                index += 1
                continue
            if char in {"'", '"'}:
                quote = char
            elif char == "\\" and index + 1 < len(line):
                index += 2
                continue
            elif char == "#" and (index == 0 or line[index - 1].isspace()):
                in_comment = True
            elif char == "<" and index + 1 < len(line) and line[index + 1] == "<":
                spec = heredoc_delimiter(line, index + 2)
                if spec[0]:
                    pending.append(spec)
                index += 2
                continue
            index += 1
        if pending:
            active = pending.pop(0)
    return bodies


FUNCTION_DEFINITION = re.compile(
    r"(?s)(?:^|[;&\n]\s*)(?:function\s+)?"
    r"(?P<name>[A-Za-z_][A-Za-z0-9_]*)\s*(?:\(\s*\))?\s*\{(?P<body>.*?)\}"
)


def invoked_function_bodies(command: str) -> list[str]:
    """Return statically defined shell-function bodies that are then invoked."""
    bodies: list[str] = []
    for match in FUNCTION_DEFINITION.finditer(command):
        name = match.group("name")
        tail = command[match.end() :]
        for clause in split_shell_clauses(tail):
            tokens = command_tokens(tokens_for(clause))
            if tokens and tokens[0] == name:
                bodies.append(match.group("body"))
                break
    return bodies


def dynamic_leading_protected_route(clause: str) -> str:
    """Detect protected command words assembled from a leading substitution."""
    stripped = clause.lstrip()
    end = -1
    if stripped.startswith("$("):
        depth = 1
        quote = ""
        index = 2
        while index < len(stripped):
            char = stripped[index]
            if quote:
                if quote == '"' and char == "\\" and index + 1 < len(stripped):
                    index += 2
                    continue
                if char == quote:
                    quote = ""
            elif char in {"'", '"'}:
                quote = char
            elif char == "(":
                depth += 1
            elif char == ")":
                depth -= 1
                if depth == 0:
                    end = index
                    break
            index += 1
    elif stripped.startswith("`"):
        end = stripped.find("`", 1)
    if end < 0:
        return ""
    suffix = tokens_for(stripped[end + 1 :])
    if suffix[:2] in (["release", "publish"], ["variant", "create"]):
        return DYNAMIC_GOVERNED_CUB
    if suffix[:2] in (
        ["create", "cluster"],
        ["delete", "cluster"],
        ["cluster", "up"],
        ["cluster", "down"],
        ["lk", "up"],
        ["lk", "down"],
    ):
        return DYNAMIC_LOCAL_KIND_LIFECYCLE
    return ""


def command_tokens(tokens: list[str]) -> list[str]:
    """Discard safe leading environment and shell execution wrappers."""
    index = 0
    while index < len(tokens) and ASSIGNMENT.match(tokens[index]):
        index += 1
    if index >= len(tokens):
        return []

    if basename(tokens[index]) == "env":
        index += 1
        while index < len(tokens):
            token = tokens[index]
            if token == "--":
                index += 1
                break
            if token in ENV_SPLIT_FLAGS:
                if index + 1 >= len(tokens):
                    return []
                # GNU env -S evaluates this value as its command line.
                return ["sh", "-c", tokens[index + 1]]
            if token.startswith("--split-string="):
                return ["sh", "-c", token.split("=", 1)[1]]
            if token.startswith("-S") and len(token) > 2:
                return ["sh", "-c", token[2:]]
            if token in ENV_VALUE_FLAGS:
                index += 2
                continue
            if ASSIGNMENT.match(token) or token.startswith("-"):
                index += 1
                continue
            break
        while index < len(tokens) and ASSIGNMENT.match(tokens[index]):
            index += 1
    while index < len(tokens) and basename(tokens[index]) in {
        "builtin",
        "command",
        "exec",
    }:
        wrapper = basename(tokens[index])
        index += 1
        while index < len(tokens) and tokens[index].startswith("-"):
            if wrapper == "exec" and tokens[index] == "-a":
                index += 2
            else:
                index += 1
    return tokens[index:]


def shell_command_lookup_only(tokens: list[str]) -> bool:
    """Recognize Bash `command -v/-V`: it reports names and executes none."""

    index = 0
    while index < len(tokens) and ASSIGNMENT.match(tokens[index]):
        index += 1
    if index < len(tokens) and basename(tokens[index]) == "builtin":
        index += 1
    if index >= len(tokens) or basename(tokens[index]) != "command":
        return False
    index += 1
    lookup = False
    while index < len(tokens):
        token = tokens[index]
        if token == "--":
            break
        if not token.startswith("-") or token == "-":
            break
        if "v" in token[1:] or "V" in token[1:]:
            lookup = True
        index += 1
    return lookup


def command_tokens_with_expansion(
    tokens: list[str], expansion_flags: list[bool]
) -> tuple[list[str], list[bool]]:
    """Apply command wrappers while retaining expansion provenance."""
    command = command_tokens(tokens)
    if not command:
        return [], []
    if len(command) <= len(tokens) and tokens[-len(command) :] == command:
        return command, expansion_flags[-len(command) :]
    # ``env -S`` synthesizes a shell command rather than returning an argv
    # suffix. Its nested script is classified separately; do not invent literal
    # provenance for a transformed word.
    return command, [any(expansion_flags)] * len(command)


COMPOUND_COMMAND_PREFIXES = frozenset({
    "(",
    "!",
    "{",
    "do",
    "elif",
    "else",
    "if",
    "then",
    "until",
    "while",
})


def normalize_terminal_compound_grouping(clause: str) -> str:
    """Remove only unquoted closing group punctuation at a clause boundary.

    The splitter can leave a subshell closer attached to the final argv word,
    including immediately before a redirection. Normalize from shell source
    while quote and escape provenance still exists: stripping punctuation from
    shlex output can turn quoted data such as ``'--help)'`` into effective help.
    Command/process substitutions have already been scanned before this source
    is tokenized, so removing their terminal closer here cannot hide a body.
    """
    normalized = list(clause)
    quote = ""
    paren_kinds: list[str] = []
    index = 0
    while index < len(clause):
        char = clause[index]
        if quote:
            if quote == '"' and char == "\\" and index + 1 < len(clause):
                index += 2
                continue
            if char == quote:
                quote = ""
            index += 1
            continue
        if char in {"'", '"'}:
            quote = char
            index += 1
            continue
        if char == "\\" and index + 1 < len(clause):
            index += 2
            continue
        if char == "(":
            previous = clause[index - 1] if index else ""
            following = clause[index + 1] if index + 1 < len(clause) else ""
            if previous in {"$", "<", ">"}:
                paren_kinds.append("substitution")
            elif previous == "(" or following == "(":
                paren_kinds.append("arithmetic")
            elif following == ")" and (previous.isalnum() or previous == "_"):
                paren_kinds.append("function")
            else:
                paren_kinds.append("group")
            index += 1
            continue
        if char != ")":
            index += 1
            continue
        paren_kind = paren_kinds.pop() if paren_kinds else "group"
        suffix_index = index + 1
        while suffix_index < len(clause) and clause[suffix_index].isspace():
            suffix_index += 1
        suffix = clause[suffix_index:]
        boundary = (
            not suffix
            or suffix[0] in ")};|&<>"
            or bool(
                re.match(
                    r"(?:[0-9]+|\{[A-Za-z_][A-Za-z0-9_]*\})?[<>]",
                    suffix,
                )
            )
        )
        if (
            paren_kind == "group"
            and "substitution" not in paren_kinds
            and "arithmetic" not in paren_kinds
            and boundary
        ):
            normalized[index] = " "
        index += 1
    return "".join(normalized)


def compound_command_payload(
    tokens: list[str], expansion_flags: list[bool]
) -> tuple[list[str], list[bool]]:
    """Expose a command following ordinary Bash compound-control syntax.

    Clause splitting already separates ``;``, newlines, pipelines and boolean
    lists. This small normalization handles the reserved words and grouping
    punctuation that can remain at the front of each resulting clause. Case
    arms retain their ``pattern)`` word, so discard that word before examining
    the arm command.
    """
    tokens = list(tokens)
    expansion_flags = list(expansion_flags)
    while tokens:
        first = tokens[0]
        if first in COMPOUND_COMMAND_PREFIXES:
            tokens.pop(0)
            expansion_flags.pop(0)
            continue
        if first.startswith("(") and first != "((" and len(first) > 1:
            tokens[0] = first[1:]
            continue
        if first.endswith(")") and first not in {")", "$("}:
            # At command position this is a case-arm pattern. A literal command
            # containing ')' would need quoting and therefore would not carry
            # the syntactic suffix here.
            tokens.pop(0)
            expansion_flags.pop(0)
            continue
        break
    if tokens[:1] == ["case"]:
        for index, token in enumerate(tokens[1:], start=1):
            if token.endswith(")"):
                return compound_command_payload(
                    tokens[index + 1 :], expansion_flags[index + 1 :]
                )
    if tokens[:1] == ["coproc"]:
        command_index = 1
        if (
            len(tokens) > 2
            and re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", tokens[1])
            and tokens[2]
            in {"(", "{", "case", "for", "if", "select", "until", "while"}
        ):
            command_index = 2
        return compound_command_payload(
            tokens[command_index:], expansion_flags[command_index:]
        )
    return tokens, expansion_flags


def option_takes_attached_value(token: str, value_flags: frozenset[str]) -> bool:
    """Recognize a long ``--flag=value`` or short ``-ffoo`` value."""
    return any(
        token.startswith(flag + "=")
        if flag.startswith("--")
        else token.startswith(flag) and token != flag
        for flag in value_flags
    )


def wrapper_command_index(
    tokens: list[str],
    start: int,
    value_flags: frozenset[str],
    *,
    skip_positionals: int = 0,
) -> int:
    """Return a transparent wrapper's actual command position.

    This intentionally never searches arbitrary later operands for a provider
    name: those operands may be option data, filenames, or ordinary command
    arguments. Unknown flags are treated as valueless; reviewed split-value
    flags are enumerated explicitly below.
    """
    index = start
    remaining = skip_positionals
    while index < len(tokens):
        token = tokens[index]
        if token == "--":
            index += 1
            while remaining and index < len(tokens):
                remaining -= 1
                index += 1
            return index
        if token in value_flags:
            index += 2
            continue
        if option_takes_attached_value(token, value_flags):
            index += 1
            continue
        if token.startswith("-"):
            index += 1
            continue
        if remaining:
            remaining -= 1
            index += 1
            continue
        break
    return index


def xargs_command_index(tokens: list[str]) -> tuple[int, set[str]]:
    """Return xargs' command position and active replacement markers."""
    index = 1
    replacements: set[str] = set()
    while index < len(tokens):
        token = tokens[index]
        if token == "--":
            return index + 1, replacements
        if token in XARGS_REQUIRED_VALUE_FLAGS:
            if index + 1 >= len(tokens):
                return len(tokens), replacements
            value = tokens[index + 1]
            if token in {"-I", "-J"}:
                replacements.add(value)
            index += 2
            continue
        if token in XARGS_OPTIONAL_VALUE_FLAGS:
            if token == "--replace":
                replacements.add("{}")
            index += 1
            continue
        matched = False
        for flag in XARGS_REQUIRED_VALUE_FLAGS:
            if flag.startswith("--") and token.startswith(flag + "="):
                value = token.split("=", 1)[1]
                if flag in {"--replace"}:
                    replacements.add(value or "{}")
                matched = True
                break
            if not flag.startswith("--") and token.startswith(flag) and token != flag:
                value = token[len(flag) :]
                if flag in {"-I", "-J"}:
                    replacements.add(value)
                matched = True
                break
        if matched:
            index += 1
            continue
        for flag in XARGS_OPTIONAL_VALUE_FLAGS:
            if flag.startswith("--") and token.startswith(flag + "="):
                if flag == "--replace":
                    replacements.add(token.split("=", 1)[1] or "{}")
                matched = True
                break
            if not flag.startswith("--") and token.startswith(flag) and token != flag:
                matched = True
                break
        if matched or token.startswith("-"):
            index += 1
            continue
        return index, replacements
    return index, replacements


def replacement_controls_executable(token: str, replacements: set[str]) -> bool:
    """Return whether runtime input can replace any part of argv[0]."""
    return any(marker and marker in token for marker in replacements)


def wrapped_command_payloads(
    tokens: list[str], expansion_flags: list[bool]
) -> tuple[list[tuple[list[str], list[bool], bool]], bool]:
    """Extract commands genuinely executed by one reviewed launcher.

    Each payload carries ``runtime_dynamic`` when the launcher repeats or
    splices runtime data into provider argv. The boolean return is an
    unresolved executable-position condition that must fail closed.
    """
    if not tokens:
        return [], False
    executable = basename(tokens[0])

    if executable == "find":
        payloads: list[tuple[list[str], list[bool], bool]] = []
        index = 1
        while index < len(tokens):
            if tokens[index] not in {"-exec", "-execdir", "-ok", "-okdir"}:
                index += 1
                continue
            start = index + 1
            end = start
            while end < len(tokens) and tokens[end] not in {";", "+"}:
                end += 1
            if start >= end:
                return payloads, True
            command = tokens[start:end]
            flags = expansion_flags[start:end]
            if replacement_controls_executable(command[0], {"{}"}):
                return payloads, True
            payloads.append((command, flags, True))
            index = end + 1
        return payloads, False

    if executable == "xargs":
        index, replacements = xargs_command_index(tokens)
        if index >= len(tokens):
            # No explicit command means xargs' fixed default `echo`.
            return [], False
        if replacement_controls_executable(tokens[index], replacements):
            return [], True
        return [(tokens[index:], expansion_flags[index:], True)], False

    if executable == "sudo":
        sudo_value_flags = frozenset({
            "--chdir", "--close-from", "--command-timeout", "--group", "--host",
            "--other-user", "--prompt", "--role", "--type", "--user",
            "-C", "-D", "-g", "-h", "-p", "-R", "-r", "-T", "-t", "-U", "-u",
        })
        index = 1
        nonexecution_mode = False
        while index < len(tokens):
            token = tokens[index]
            if token == "--":
                break
            if token in {"--edit", "--list", "-e", "-l"}:
                nonexecution_mode = True
                index += 1
                continue
            if token in sudo_value_flags:
                index += 2
                continue
            if option_takes_attached_value(token, sudo_value_flags):
                index += 1
                continue
            if token.startswith("-"):
                index += 1
                continue
            break
        if nonexecution_mode:
            # These modes edit named files or list policy; later provider words
            # are operands, not executed commands.
            return [], False

    if executable == "script":
        option_end = next(
            (
                index
                for index, token in enumerate(tokens[1:], start=1)
                if token == "--" or not token.startswith("-")
            ),
            len(tokens),
        )
        for index, token in enumerate(tokens[1:option_end], start=1):
            if token in {"-c", "--command"}:
                if index + 1 >= len(tokens):
                    return [], True
                return [
                    (
                        ["sh", "-c", tokens[index + 1]],
                        [False, False, expansion_flags[index + 1]],
                        False,
                    )
                ], False
            if token.startswith("--command="):
                return [
                    (
                        ["sh", "-c", token.split("=", 1)[1]],
                        [False, False, expansion_flags[index]],
                        False,
                    )
                ], False
            if (
                token.startswith("-")
                and not token.startswith("--")
                and "c" in token[1:]
            ):
                suffix = token[token.index("c") + 1 :]
                if suffix:
                    command = suffix
                    command_expansion = expansion_flags[index]
                elif index + 1 < len(tokens):
                    command = tokens[index + 1]
                    command_expansion = expansion_flags[index + 1]
                else:
                    return [], True
                return [
                    (
                        ["sh", "-c", command],
                        [False, False, command_expansion],
                        False,
                    )
                ], False
        # BSD/macOS script accepts `[file [command ...]]` without `-c`.
        file_index = wrapper_command_index(
            tokens,
            1,
            frozenset({"-T", "-t"}),
        )
        command_index = file_index + 1
        return (
            [(tokens[command_index:], expansion_flags[command_index:], False)]
            if command_index < len(tokens)
            else [],
            False,
        )

    if executable == "watch":
        value_flags = frozenset({"--equexit", "--interval", "-n", "-q"})
        command_index = 1
        while command_index < len(tokens):
            token = tokens[command_index]
            if token == "--":
                command_index += 1
                break
            if token in value_flags:
                command_index += 2
                continue
            if option_takes_attached_value(token, value_flags):
                command_index += 1
                continue
            if token.startswith("-"):
                return [], True
            break
        if command_index >= len(tokens):
            return [], False
        direct_exec = any(
            token in {"--exec", "-x"} for token in tokens[1:command_index]
        )
        if direct_exec:
            return [
                (
                    tokens[command_index:],
                    expansion_flags[command_index:],
                    True,
                )
            ], False
        command = " ".join(tokens[command_index:])
        return [
            (
                ["sh", "-c", command],
                [False, False, any(expansion_flags[command_index:])],
                True,
            )
        ], False

    value_flags_by_wrapper = {
        "doas": frozenset({"-a", "-C", "-u"}),
        "nice": frozenset({"--adjustment", "-n"}),
        "nohup": frozenset(),
        "setsid": frozenset(),
        "stdbuf": frozenset({"--input", "--output", "--error", "-i", "-o", "-e"}),
        "sudo": frozenset({
            "--chdir", "--close-from", "--command-timeout", "--group", "--host",
            "--other-user", "--prompt", "--role", "--type", "--user",
            "-C", "-D", "-g", "-h", "-p", "-R", "-r", "-T", "-t", "-U", "-u",
        }),
        "time": frozenset({"--format", "--output", "-f", "-o"}),
    }
    if executable in value_flags_by_wrapper:
        index = wrapper_command_index(tokens, 1, value_flags_by_wrapper[executable])
        return (
            [(tokens[index:], expansion_flags[index:], False)]
            if index < len(tokens)
            else [],
            False,
        )

    if executable == "timeout":
        index = wrapper_command_index(
            tokens,
            1,
            frozenset({"--kill-after", "--signal", "-k", "-s"}),
            skip_positionals=1,
        )
        return (
            [(tokens[index:], expansion_flags[index:], False)]
            if index < len(tokens)
            else [],
            False,
        )

    if executable == "chrt":
        prefix_end = next(
            (
                index
                for index, token in enumerate(tokens[1:], start=1)
                if not token.startswith("-")
            ),
            len(tokens),
        )
        if any(token in {"--pid", "-p"} for token in tokens[1:prefix_end]):
            return [], False
        index = wrapper_command_index(
            tokens,
            1,
            frozenset({
                "--sched-deadline", "--sched-period", "--sched-runtime",
                "--period", "--runtime", "-D", "-P", "-T",
            }),
            skip_positionals=1,
        )
        return (
            [(tokens[index:], expansion_flags[index:], False)]
            if index < len(tokens)
            else [],
            False,
        )

    if executable == "ionice":
        prefix_end = next(
            (
                index
                for index, token in enumerate(tokens[1:], start=1)
                if not token.startswith("-")
            ),
            len(tokens),
        )
        if any(
            token in {"--pid", "--pgid", "--uid", "-p", "-P", "-u"}
            for token in tokens[1:prefix_end]
        ):
            return [], False
        index = wrapper_command_index(
            tokens,
            1,
            frozenset({"--class", "--classdata", "--classdata", "-c", "-n"}),
        )
        return (
            [(tokens[index:], expansion_flags[index:], False)]
            if index < len(tokens)
            else [],
            False,
        )

    if executable == "parallel":
        value_flags = frozenset({
            "--arg-file", "--delay", "--jobs", "--joblog", "--results",
            "--sshlogin", "--sshloginfile", "--timeout", "--wd", "--workdir",
            "-a", "-j", "-S",
        })
        index = 1
        while index < len(tokens):
            token = tokens[index]
            if token == "--":
                index += 1
                break
            if token in value_flags:
                index += 2
                continue
            if option_takes_attached_value(token, value_flags):
                index += 1
                continue
            if token.startswith("-"):
                # Parallel has a very broad evolving option grammar. An
                # unreviewed option may consume the apparent provider word as
                # data, so its command position cannot be bound here.
                return [], True
            break
        if index >= len(tokens):
            return [], False
        if replacement_controls_executable(tokens[index], {"{}", "{.}", "{/}"}):
            return [], True
        # GNU Parallel templates are evaluated as shell source after runtime
        # replacement. Preserve the complete template rather than quoting a
        # one-token script into inert data.
        command = " ".join(tokens[index:])
        return [
            (
                ["sh", "-c", command],
                [False, False, any(expansion_flags[index:])],
                True,
            )
        ], False

    return [], False


def is_help(tokens: list[str]) -> bool:
    """Return token-level last-one-wins help state after effect preclassification.

    This helper is intentionally not option-arity aware. Protected Cub,
    kubectl, kind, and local-kind effects must be classified before callers use
    it; their only exemption is the strict literal grammar below.
    """
    return boolean_alias_state(tokens, frozenset({"--help", "-h"})) is True


def next_positional(tokens: list[str], start: int, value_flags: frozenset[str]) -> tuple[str, int]:
    index = start
    while index < len(tokens):
        token = tokens[index]
        if token == "--":
            return "", index
        if token in value_flags:
            index += 2
            continue
        if token.startswith("--") and "=" in token:
            index += 1
            continue
        if token.startswith("-"):
            index += 1
            continue
        return token, index
    return "", index


def next_cub_command_word(tokens: list[str], start: int) -> tuple[str, int, bool]:
    """Find one Cub command word without guessing an unknown option's arity.

    Cobra permits persistent and leaf options before subcommands. The hook
    knows the exact reviewed root value flags and booleans. An unknown split
    option before the noun or verb is ambiguous: treating its following value
    as a command word can bypass the protected leaf entirely. Equals-form
    options are self-contained and may be skipped; strict leaf classifiers
    still inspect the complete argv before granting any interactive route.
    """

    index = start
    while index < len(tokens):
        token = tokens[index]
        if token == "--":
            return "", index, False
        option = token.split("=", 1)[0]
        if option in CUB_VALUE_FLAGS:
            index += 1 if "=" in token else 2
            continue
        if option in CUB_COMMAND_BOOLEAN_FLAGS:
            index += 1
            continue
        if token.startswith("--") and "=" in token:
            index += 1
            continue
        if token.startswith("-"):
            return "", index, True
        return token, index, False
    return "", index, False


def next_function_name(
    tokens: list[str], start: int, value_flags: frozenset[str]
) -> tuple[str, int]:
    """Read a function name, including Cobra's explicit ``--`` separator.

    Cub documents the separator when a function's own named arguments would
    otherwise look like Cub flags. The first word after that separator is still
    the function; later words are function arguments.
    """
    value, index = next_positional(tokens, start, value_flags)
    if value or index >= len(tokens) or tokens[index] != "--":
        return value, index
    index += 1
    return (tokens[index], index) if index < len(tokens) else ("", index)


def boolean_flag_state(tokens: list[str], name: str) -> bool | None:
    """Return a literal Cobra boolean, or ``None`` for a dynamic value.

    A repeated boolean flag is last-one-wins. Stop at ``--`` so a literal
    argument cannot affect classification. Shell variables and substitutions
    are deliberately not guessed: the hook observes source text before Bash
    expands it, so treating an unknown value as true could turn a real write
    into an apparent dry run.
    """
    value: bool | None = False
    for token in tokens:
        if token == "--":
            break
        flag, separator, raw = token.partition("=")
        if flag != name:
            continue
        if not separator:
            value = True
            continue
        normalized = raw.strip().lower()
        if normalized in TRUE_FLAG_VALUES:
            value = True
        elif normalized in FALSE_FLAG_VALUES:
            value = False
        else:
            value = None
    return value


def boolean_flag_enabled(tokens: list[str], name: str) -> bool:
    """Fail closed when a flag that adds an effect may be enabled."""
    return boolean_flag_state(tokens, name) is not False


def boolean_flag_statically_enabled(tokens: list[str], name: str) -> bool:
    """Trust a safety exemption only when its final value is literal true."""
    return boolean_flag_state(tokens, name) is True


def boolean_alias_state(tokens: list[str], names: frozenset[str]) -> bool | None:
    """Return the last literal value across aliases bound to one pflag bool."""
    value: bool | None = False
    for token in tokens:
        if token == "--":
            break
        flag, separator, raw = token.partition("=")
        if flag not in names:
            continue
        if not separator:
            value = True
            continue
        normalized = raw.strip().lower()
        if normalized in TRUE_FLAG_VALUES:
            value = True
        elif normalized in FALSE_FLAG_VALUES:
            value = False
        else:
            value = None
    return value


def static_cub_identifier(value: str) -> bool:
    """Recognize one non-expanded Cub slug/ID-like command value."""
    return bool(re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9._:@+-]*", value))


def exact_cub_space(value: str) -> bool:
    """Return whether argv names one literal, non-wildcard Space."""
    return value != "*" and static_cub_identifier(value)


def exact_cub_target(value: str) -> bool:
    """Return whether argv binds one literal ``space/target`` pair."""
    parts = value.split("/")
    return len(parts) == 2 and all(exact_cub_space(part) for part in parts)


def static_nonempty_value(value: str) -> bool:
    """Reject values whose runtime bytes depend on shell expansion."""
    return bool(value) and not any(marker in value for marker in ("$", "`"))


def effective_value_flag(tokens: list[str], names: frozenset[str]) -> str:
    """Return the last value supplied through equivalent Cobra aliases."""
    value = ""
    index = 0
    while index < len(tokens):
        token = tokens[index]
        if token == "--":
            break
        if token in names:
            value = tokens[index + 1] if index + 1 < len(tokens) else ""
            index += 2
            continue
        matched = False
        for name in names:
            if token.startswith(name + "="):
                value = token.split("=", 1)[1]
                matched = True
                break
            if (
                len(name) == 2
                and name.startswith("-")
                and not name.startswith("--")
                and token.startswith(name)
                and len(token) > 2
            ):
                value = token[2:]
                matched = True
                break
        index += 1
        if matched:
            continue
    return value


def value_flag_present(tokens: list[str], name: str) -> bool:
    """Return whether a value-bearing flag's effective value is non-empty."""
    return bool(effective_value_flag(tokens, frozenset({name})))


def unreviewed_release_boundary_selector(tokens: list[str]) -> str:
    """Return a v0.2.32 boundary selector outside the reviewed tag contract."""
    selector = effective_value_flag(tokens, frozenset({"--revision"}))
    if selector.startswith(UNREVIEWED_RELEASE_BOUNDARY_PREFIXES):
        return selector
    return ""


def any_value_flag_present(tokens: list[str], name: str) -> bool:
    """Match pflag StringSlice semantics: later occurrences append, not replace."""
    return any(bool(value) for value in flag_values(tokens, name))


def cub_output_format(tokens: list[str]) -> str:
    """Return Cobra's effective cub output format, including ``-ojson``.

    Output flags are last-one-wins across the long and short aliases. Stop at
    ``--`` so a literal command argument cannot affect classification.
    """
    value = ""
    for index, token in enumerate(tokens):
        if token == "--":
            break
        if token in {"--output", "-o"}:
            value = tokens[index + 1] if index + 1 < len(tokens) else ""
        elif token.startswith("--output=") or token.startswith("-o="):
            value = token.split("=", 1)[1]
        elif token.startswith("-o") and not token.startswith("--") and len(token) > 2:
            value = token[2:]
    return value.strip()


def cub_output_risk(
    tokens: list[str], *, allow_reviewed_unit_projection: bool = False
) -> str:
    """Classify Cub output that is secret-capable or outside the pinned grammar."""
    modern = cub_output_format(tokens)
    if modern:
        kind, _separator, _selector = modern.partition("=")
        kind = kind.lower()
        if kind in {"json", "yaml", "jq", "yq"}:
            if allow_reviewed_unit_projection and (
                (kind == "jq" and exact_reviewed_unit_projection(tokens))
                or (kind == "json" and exact_reviewed_dependency_projection(tokens))
            ):
                return ""
            return "serialized-secret"
        if kind in {"custom-columns", "mutations", "name", "wide"}:
            # Custom columns name their own field paths, which are classified
            # separately by columns_disclose_worker_secret. Every other get or
            # list renderer keeps its fixed human view.
            return ""
        # Exact v0.2.11/v0.2.15 Cub accepts only json, yaml, name, wide,
        # mutations, jq, yq, and custom-columns. File-backed, go-template, and
        # jsonpath spellings are kubectl vocabulary and fail client-side. The
        # raw hook cannot authenticate the executable bytes, so unknown output
        # grammar remains governed without mislabeling it as proven disclosure.
        return "unreviewed-output-format"
    # Cub still honors these hidden deprecated flags on every standard get or
    # list command. They are absent from Cobra help, so the static tree cannot
    # discover them; the pinned source review and parameter cases cover them.
    if boolean_flag_enabled(tokens, "--json"):
        return "serialized-secret"
    if boolean_flag_enabled(tokens, "--yaml"):
        return "serialized-secret"
    if effective_value_flag(tokens, frozenset({"--jq"})):
        return "serialized-secret"
    return (
        "serialized-secret"
        if effective_value_flag(tokens, frozenset({"--yq"}))
        else ""
    )


def exact_reviewed_unit_projection(tokens: list[str]) -> bool:
    """Admit only the two literal Unit projections used by the ring reader.

    These selectors expose a bounded identity/revision record, not the Unit
    body or BridgeWorker. Keep the complete argv shape exact so another jq
    expression, extra flag, duplicate output flag, or selector alias remains
    governed by the serialized-secret rule.
    """
    unit_get_jq = (
        "{Unit:{UnitID:.Unit.UnitID,Slug:.Unit.Slug,SpaceID:.Unit.SpaceID,SpaceSlug:.Unit.SpaceSlug,"
        "HeadRevisionNum:.Unit.HeadRevisionNum,UpstreamRevisionNum:.Unit.UpstreamRevisionNum,"
        "UpstreamUnitID:.Unit.UpstreamUnitID},UpstreamUnit:(if .UpstreamUnit then "
        "{UnitID:.UpstreamUnit.UnitID,Slug:.UpstreamUnit.Slug,HeadRevisionNum:.UpstreamUnit.HeadRevisionNum} "
        "else null end),Space:{SpaceID:.Space.SpaceID,Slug:.Space.Slug}}"
    )
    unit_list_jq = (
        "[.[]|{Unit:{UnitID:.Unit.UnitID,Slug:.Unit.Slug,SpaceID:.Unit.SpaceID,SpaceSlug:.Unit.SpaceSlug,"
        "HeadRevisionNum:.Unit.HeadRevisionNum,UpstreamRevisionNum:.Unit.UpstreamRevisionNum,"
        "UpstreamUnitID:.Unit.UpstreamUnitID}}]"
    )
    if len(tokens) == 7 and tokens[:2] == ["unit", "get"]:
        return (
            static_cub_identifier(tokens[2])
            and tokens[3] == "--space"
            and exact_cub_space(tokens[4])
            and tokens[5] == "-o"
            and tokens[6] == "jq=" + unit_get_jq
        )
    if len(tokens) == 7 and tokens[:2] == ["unit", "list"]:
        return (
            tokens[2:5] == ["--space", tokens[3], "--quiet"]
            and exact_cub_space(tokens[3])
            and tokens[5:] == ["-o", "jq=" + unit_list_jq]
        )
    return False


def exact_reviewed_dependency_projection(tokens: list[str]) -> bool:
    """Admit only the named-context Target/Worker selections proved on v0.6.8.

    Org-wide scope is still governed by the earlier scope rule. This
    exception does not admit arbitrary selectors, filters, aliases or output
    flags. The caller permits it only in direct, literal shell commands.
    """
    if len(tokens) != 10 or tokens[0] != "--context" or not static_cub_identifier(tokens[1]):
        return False
    words = tokens[2:]
    selections = {
        "target": "Slug,TargetID,SpaceID,OrganizationID,BridgeWorkerID,DeleteGates,"
                  "TriggerIDs,TriggerFilterID,BridgeWorker.Slug",
        "worker": "Slug,BridgeWorkerID,SpaceID,OrganizationID,DeleteGates",
    }
    return (
        words[0] in selections
        and words[1:3] == ["list", "--space"]
        and exact_cub_space(words[3])
        and words[4:] == ["--select", selections[words[0]], "-o", "json"]
    )


def flag_values(tokens: list[str], name: str) -> list[str]:
    """Collect each pre-separator value of a repeatable long Cobra flag."""
    values: list[str] = []
    index = 0
    while index < len(tokens):
        token = tokens[index]
        if token == "--":
            break
        if token == name:
            values.append(tokens[index + 1] if index + 1 < len(tokens) else "")
            index += 2
            continue
        if token.startswith(name + "="):
            values.append(token.split("=", 1)[1])
        index += 1
    return values


def columns_disclose_worker_secret(noun: str, tokens: list[str]) -> bool:
    """Detect dynamic columns that traverse the expanded worker object.

    Up to cub v0.5.2 only ``unit list`` and ``unit tree`` read these flags; every
    other list accepted them and rendered its fixed table anyway. cub v0.5.3 made
    ``--columns`` and ``-o custom-columns`` work on every list, so the same field
    path now prints the worker credential from ``target``, ``trigger``,
    ``invocation`` and ``worker`` lists as well. ``worker list`` always selects
    ``Secret`` from the server, so there the bare spelling reaches it too.
    """
    column_specs = flag_values(tokens, "--columns")
    if not column_specs:
        output = cub_output_format(tokens)
        if output.lower().startswith("custom-columns="):
            column_specs = [output.split("=", 1)[1]]

    def sensitive(column: str) -> bool:
        path = column.strip()
        # The reflection renderer accepts the entity-qualified spelling too.
        for prefix in ("Unit.", "Target.", "Trigger.", "Invocation."):
            if path.startswith(prefix):
                path = path[len(prefix) :]
                break
        if noun == "worker":
            # The rows are the workers themselves, so the provider reads a bare
            # field name off the BridgeWorker as well as the qualified one.
            bare = path
            if bare.startswith("BridgeWorker."):
                bare = bare[len("BridgeWorker.") :]
            return (
                bare == ""
                or bare == "BridgeWorker"
                or bare.startswith("Secret")
                or bare.startswith("ClaimToken")
            )
        return (
            path == "BridgeWorker"
            or path.startswith("BridgeWorker.Secret")
            or path.startswith("BridgeWorker.ClaimToken")
        )

    return any(sensitive(column) for spec in column_specs for column in spec.split(","))


def function_output_writes_file(tokens: list[str]) -> bool:
    """Return whether Cub's effective function display writes ConfigData.

    ``-O/--output-file`` is consulted only by the data display path. An
    explicit ``--show`` wins over the deprecated ``--data-only`` alias.
    Dynamic selector values fail closed because they may expand to ``data``.
    """
    if not effective_value_flag(tokens, frozenset({"--output-file", "-O"})):
        return False
    show = effective_value_flag(tokens, frozenset({"--show"})).strip().lower()
    if show:
        return show == "data" or not static_nonempty_value(show)
    return boolean_flag_enabled(tokens, "--data-only")


def composed_function_effect(tokens: list[str], label: str) -> str:
    """Classify flags that add writes or unreviewed executions to a function."""
    if function_output_writes_file(tokens):
        return f"{label} --output-file"
    if boolean_flag_enabled(tokens, "--update-apply-gates"):
        return f"{label} --update-apply-gates"
    if any_value_flag_present(tokens, "--trigger"):
        return f"{label} --trigger"
    if any_value_flag_present(tokens, "--invocation"):
        return f"{label} --invocation"
    if value_flag_present(tokens, "--worker"):
        return f"{label} --worker"
    return ""


def bounded_space_effect(tokens: list[str], label: str) -> str:
    """Require one literal Space for a raw remote operation."""
    space = effective_value_flag(tokens, frozenset({"--space"}))
    if space == "*":
        return f"{label} --space *"
    if not exact_cub_space(space):
        return f"{label} explicit-space-required"
    return ""


def approved_execution(tokens: list[str]) -> bool:
    if len(tokens) < 2 or basename(tokens[0]) != "pilot" or tokens[1] != "execute-approved":
        return False
    try:
        separator = tokens.index("--", 2)
    except ValueError:
        return False
    command = tokens[separator + 1 :]
    positional, noun_index = next_positional(command, 1, CUB_VALUE_FLAGS) if command[:1] == ["cub"] else ("", 0)
    if positional == "variant":
        return command[noun_index:noun_index + 2] == ["variant", "promote"] and len(command) > noun_index + 2
    if len(command) >= 4 and command[:2] == ["cub", "unit"] and command[2] in {"apply", "approve"}:
        for index, token in enumerate(command[3:], start=3):
            revision = ""
            if token == "--revision" and index + 1 < len(command):
                revision = command[index + 1]
            elif token.startswith("--revision="):
                revision = token.split("=", 1)[1]
            if revision.isdigit() and int(revision) > 0:
                return True
    return False


def protected_kind(tokens: list[str], expansion_flags: list[bool]) -> str:
    control_end = tokens.index("--") if "--" in tokens else len(tokens)
    if any(expansion_flags[:control_end]):
        return DYNAMIC_LOCAL_KIND_LIFECYCLE
    verb, verb_index = next_positional(tokens, 0, KIND_GLOBAL_VALUE_FLAGS)
    noun, _ = next_positional(tokens, verb_index + 1, KIND_GLOBAL_VALUE_FLAGS)
    if verb in {"create", "delete"} and noun == "cluster":
        return f"kind {verb} cluster"
    return ""


def protected_pilot_local_kind(
    tokens: list[str], expansion_flags: list[bool] | None = None
) -> str:
    """Recognize installed, checkout, direct-helper, and Python wrapper forms."""
    if not tokens:
        return ""
    flags = list(expansion_flags or [False] * len(tokens))
    if len(flags) != len(tokens):
        flags = [True] * len(tokens)
    executable = basename(tokens[0])
    payload = tokens[1:]
    payload_flags = flags[1:]
    if re.fullmatch(r"python(?:\d+(?:\.\d+)*)?", executable):
        script_index = next(
            (
                index
                for index, token in enumerate(payload)
                if basename(token) in {"pilot", "pilot-local-kind-live-proof"}
            ),
            -1,
        )
        if script_index < 0:
            if any(payload_flags) and any(
                token == "--live-kind" or token.startswith("--live-kind=")
                for token in payload
            ):
                return PILOT_LOCAL_KIND_LIVE_ROUTE
            return ""
        executable = basename(payload[script_index])
        payload = payload[script_index + 1 :]
        payload_flags = payload_flags[script_index + 1 :]
    if executable == "pilot":
        try:
            route_index = payload.index("local-kind-live-proof")
        except ValueError:
            if any(payload_flags) and any(
                token == "--live-kind" or token.startswith("--live-kind=")
                for token in payload
            ):
                return PILOT_LOCAL_KIND_LIVE_ROUTE
            return ""
        # Protection is deliberately broader than the accepted dispatcher
        # grammar. Misordered root/helper flags can make argparse exit instead
        # of showing help; retaining every surrounding word prevents the
        # general help shortcut from approving that invalid non-help argv.
        payload = payload[:route_index] + payload[route_index + 1 :]
        payload_flags = (
            payload_flags[:route_index] + payload_flags[route_index + 1 :]
        )
    elif executable != "pilot-local-kind-live-proof":
        return ""
    return (
        PILOT_LOCAL_KIND_LIVE_ROUTE
        if any(
            token == "--live-kind" or token.startswith("--live-kind=")
            for token in payload
        )
        or any(payload_flags)
        else ""
    )


def protected_cub(
    tokens: list[str],
    expansion_flags: list[bool],
    *,
    allow_reviewed_unit_projection: bool = False,
) -> str:
    control_end = tokens.index("--") if "--" in tokens else len(tokens)
    if any(expansion_flags[:control_end]):
        # The hook receives shell source, not expanded argv. A variable or
        # command substitution can therefore synthesize a mutation flag,
        # credential selector, output format, wildcard scope, noun, or verb.
        # Literal argv is the only defensible basis for a safety exemption.
        return "cub <dynamic-argument>"
    noun, noun_index, ambiguous = next_cub_command_word(tokens, 0)
    if ambiguous:
        return "cub <ambiguous-pre-verb-option>"
    if noun in {"apply", "docgen", "run", "upgrade"}:
        # These are root leaves; the first positional after them is an argument
        # (a function name for run, a file for apply), not a Cub subcommand.
        verb, verb_index = "", noun_index
    else:
        verb, verb_index, ambiguous = next_cub_command_word(tokens, noun_index + 1)
        if ambiguous:
            return "cub <ambiguous-pre-verb-option>"
    if noun == "docgen":
        return "cub docgen"
    if noun == "helm":
        return "cub helm plugin-execution"
    if noun == "gitops":
        verb, _ = next_positional(tokens, noun_index + 1, CUB_VALUE_FLAGS)
        if verb in GITOPS_MUTATION_VERBS:
            return f"cub gitops {verb}"
        return "cub gitops plugin-execution"
    if noun == "lk":
        verb, _ = next_positional(tokens, noun_index + 1, CUB_VALUE_FLAGS)
        if verb in {"up", "down"}:
            return f"cub lk {verb}"
        return "cub lk plugin-execution"
    if noun == SCOUT_PLUGIN_NOUN:
        # `cub scout ...` is decided by the Scout hook, like `cub-scout ...`.
        return ""
    if noun and noun not in REVIEWED_CORE_CUB_NOUNS:
        # Cobra dispatches any unknown root word to a same-named installed
        # plugin via syscall.Exec, passing the active access token as CUB_TOKEN.
        # Static help cannot enumerate that ambient executable surface.
        return "cub unreviewed-plugin-or-root"
    if noun == "variant" and verb and verb not in REVIEWED_VARIANT_VERBS:
        # A reviewed root noun can gain a new leaf between compatibility
        # captures. Do not let that new leaf inherit read-only status merely
        # because the parent noun was already known.
        return "cub variant unreviewed-operation"
    if (
        noun == "unit"
        and verb
        and verb not in REVIEWED_UNIT_READ_VERBS
        and verb not in UNIT_MUTATION_VERBS
    ):
        return "cub unit unreviewed-operation"
    if noun == "k8s" and verb and verb not in REVIEWED_K8S_VERBS:
        # The v0.4.5 `refresh` addition proved that this subtree can grow
        # ConfigHub writes as well as reads. Unknown leaves therefore stop
        # until an exact command/source review classifies them.
        return "cub k8s unreviewed-operation"
    if noun == "unit" and verb == "blame":
        # v0.4.5 blame joins current Unit data to mutation, revision, user, and
        # upstream-Unit history. Its path/resource filters run only after that
        # provider traversal, and output/upstream modifiers do not establish a
        # bounded or redacted assistant read. Keep every raw shape stopped;
        # strict literal help is still exempted by the pre-help classifier.
        return "cub unit blame"
    if noun in KEY_AUTHORITY_NOUNS and verb == "key":
        operation, _ = next_positional(
            tokens, verb_index + 1, KEY_AUTHORITY_VALUE_FLAGS
        )
        if operation in KEY_AUTHORITY_OPERATIONS:
            return f"cub {noun} key {operation}"
        # The installed client can grow more key-lifecycle leaves without the
        # older reviewed static surfaces seeing them. Keep that subtree closed
        # until an exact artifact/source review names each operation.
        return f"cub {noun} key unreviewed-operation"
    if (
        noun == "release"
        and verb == "publish"
        and unreviewed_release_boundary_selector(tokens)
    ):
        return "cub release publish unreviewed-boundary-selector"
    if noun in UNBOUNDED_ORGANIZATION_LIST_NOUNS and verb == "list":
        return f"cub {noun} list bounded-route-required"
    if noun == "space" and verb == "new-prefix":
        return "cub space new-prefix bounded-route-required"
    if noun == "k8s" and verb in {"get", "types"}:
        explicit_space = effective_value_flag(tokens, frozenset({"--space"}))
        explicit_target = effective_value_flag(tokens, frozenset({"--target"}))
        if exact_cub_target(explicit_target) and (
            not explicit_space or exact_cub_space(explicit_space)
        ):
            explicit_space = explicit_space or explicit_target.split("/", 1)[0]
        if explicit_space == "*":
            return f"cub k8s {verb} --space *"
        if not exact_cub_space(explicit_space):
            return f"cub k8s {verb} explicit-space-required"
    if noun == "cluster" and verb == "list":
        return "cub cluster list bounded-route-required"
    unit_tree_space = (
        effective_value_flag(tokens, frozenset({"--space"}))
        if noun == "unit" and verb == "tree"
        else ""
    )
    if noun == "unit" and verb == "tree" and unit_tree_space == "*":
        return "cub unit tree --space *"
    if noun == "worker" and verb in {"list-function", "list-status"}:
        explicit_space = effective_value_flag(tokens, frozenset({"--space"}))
        if explicit_space == "*":
            return f"cub worker {verb} --space *"
        if not exact_cub_space(explicit_space):
            return f"cub worker {verb} explicit-space-required"
    if noun == "unit" and verb in {"data", "mutation-sources"}:
        # v0.2.34 made these selector-capable reads: with --where they can read
        # every matching Unit in one request, and --space "*" is explicitly
        # organization-wide. Do not infer a Space from a slash-qualified Unit
        # or from ambient context. One effective literal --space keeps both an
        # exact-Unit read and an exact-Space selector read bounded.
        explicit_space = effective_value_flag(tokens, frozenset({"--space"}))
        if explicit_space == "*":
            return f"cub unit {verb} --space *"
        if not exact_cub_space(explicit_space):
            return f"cub unit {verb} explicit-space-required"
    if noun == "resource" and verb == "data":
        # v0.8.30: prints one stored resource, named kubectl-style as
        # <kind>/[<namespace>/]<name>, found across the organization when no
        # Space is given. Bound it like `unit data`, and treat a Secret kind
        # (matched in any case, with kubectl's .group suffix) as a secret read.
        if any(
            re.match(r"secrets?[./]", token, re.I) or token.lower() in {"secret", "secrets"}
            for token in tokens[verb_index + 1 :]
            if not token.startswith("-")
        ):
            return "cub resource data secret"
        explicit_space = effective_value_flag(tokens, frozenset({"--space"}))
        if explicit_space == "*":
            return "cub resource data --space *"
        if not exact_cub_space(explicit_space):
            return "cub resource data explicit-space-required"
    remote_list = noun in REMOTE_SPACE_LIST_NOUNS and verb == "list"
    explicit_space = (
        effective_value_flag(tokens, frozenset({"--space"}))
        if remote_list
        else ""
    )
    if remote_list and explicit_space == "*":
        return f"cub {noun} list --space *"
    output_risk = (
        cub_output_risk(
            tokens,
            allow_reviewed_unit_projection=allow_reviewed_unit_projection,
        )
        if noun in BRIDGE_WORKER_EXPANDING_READ_NOUNS
        and verb in {"get", "list"}
        else ""
    )
    if output_risk:
        # The pinned clients expose BridgeWorker credentials through their
        # valid serialized formats. Unsupported output vocabulary is a
        # separately named fail-closed condition, not claimed disclosure.
        return f"cub {noun} {verb} {output_risk}"
    if (
        noun in BRIDGE_WORKER_EXPANDING_READ_NOUNS
        and verb in {"list", "tree"}
        and columns_disclose_worker_secret(noun, tokens)
    ):
        return f"cub {noun} {verb} worker-secret-column"
    if noun == "unit" and verb == "tree" and not exact_cub_space(unit_tree_space):
        return "cub unit tree explicit-space-required"
    if remote_list and not exact_cub_space(explicit_space):
        # Cub treats an empty or wildcard context default as org-wide for
        # OrgLevel commands. The hook cannot authenticate that ambient
        # context, so raw list reads must carry their bounded Space. Run this
        # after more specific credential/output classifiers so diagnostics
        # retain the strongest observed effect.
        return f"cub {noun} list explicit-space-required"
    if (
        noun == "revision"
        and verb == "data"
        and value_flag_present(tokens, "--filename")
    ):
        return "cub revision data --output-file"
    if noun == "unit-action" and verb in {
        "data",
        "livedata",
        "livestate",
        "bridgestate",
    } and value_flag_present(tokens, "--filename"):
        return f"cub unit-action {verb} --output-file"
    if noun == "unit" and verb in {
        "data",
        "livedata",
        "livestate",
        "bridgestate",
    } and effective_value_flag(
        tokens, frozenset({"--output-file", "-O", "--filename"})
    ):
        return f"cub unit {verb} --output-file"
    if (
        noun == "unit"
        and verb in {"data", "livedata", "livestate", "bridgestate"}
        and effective_value_flag(tokens, frozenset({"--output"}))
    ):
        # v0.2.11/v0.2.15 used --output as a deprecated filename alias;
        # v0.2.34 uses it as the ordinary display-format flag. This raw hook
        # cannot authenticate which client is executing, so retain a typed
        # compatibility stop without claiming modern Cub writes a file.
        return f"cub unit {verb} version-dependent-output"
    if (
        noun == "unit"
        and verb == "get"
        and boolean_flag_enabled(tokens, "--data-only")
        and value_flag_present(tokens, "--filename")
    ):
        return "cub unit get --output-file"
    if noun == "run":
        if boolean_flag_enabled(tokens, "--protect") or any_value_flag_present(
            tokens, "--clearance"
        ):
            return "cub run protection-or-clearance"
        if boolean_alias_state(tokens, frozenset({"--reload", "--reset"})) is not False:
            return "cub run cache-refresh"
        function, _ = next_function_name(tokens, noun_index + 1, CUB_RUN_VALUE_FLAGS)
        composed = composed_function_effect(tokens, "cub run")
        if composed:
            return composed
        if function in READ_ONLY_CUB_RUN_FUNCTIONS:
            return bounded_space_effect(tokens, "cub run")
        return f"cub run {function}".rstrip()
    if noun == "cluster":
        verb, _ = next_positional(tokens, noun_index + 1, CUB_VALUE_FLAGS)
        if noun == "cluster" and verb == "open":
            print_url = boolean_flag_statically_enabled(tokens, "--print-url")
            # The explicit URL-only shape returns before Cub reads or copies the
            # Argo admin password. Default `cluster open` resolves that password
            # and copies or prints it, so it is credential-sensitive.
            return "" if print_url else "cub cluster open"
        if verb == "down" and boolean_flag_enabled(tokens, "--delete-config"):
            # Operator decision 2026-09-23 (#1192): the plain teardown becomes
            # host-reviewable, but `--delete-config` also deletes the local
            # cluster's ConfigHub Space(s) (v0.5.3 `cub cluster down --help`).
            # Keep that combination a concrete destructive stop, routed to
            # Pilot's dependency-aware teardown planner instead of one ask.
            return "cub cluster down --delete-config"
        if verb == "detach" and boolean_flag_enabled(tokens, "--delete-config"):
            # cub v0.8.22 added `cluster attach`/`detach`. `detach
            # --delete-config` deletes the cluster's ConfigHub Spaces and its
            # service account, the same effect as `down --delete-config`, so it
            # is the same stop.
            return "cub cluster detach --delete-config"
        if verb in {"up", "down"}:
            return f"cub {noun} {verb}"
        # Any other cluster verb (attach, detach, or one added in a later cub)
        # is not a known read, so it asks. It used to run with no prompt.
        return f"cub cluster {verb}" if verb else ""
    if noun == "space":
        verb, _ = next_positional(tokens, noun_index + 1, CUB_VALUE_FLAGS)
        if verb in SPACE_MUTATION_VERBS:
            return f"cub space {verb}"
        if verb and verb not in REVIEWED_SPACE_READ_VERBS:
            return "cub space unreviewed-operation"
        return ""
    if noun == "function":
        verb, verb_index = next_positional(tokens, noun_index + 1, CUB_RUN_VALUE_FLAGS)
        if verb == "invoke":
            verb = "do"
        if verb == "do" and (
            boolean_flag_enabled(tokens, "--protect")
            or any_value_flag_present(tokens, "--clearance")
        ):
            return "cub function do protection-or-clearance"
        if verb == "list":
            where_value = effective_value_flag(tokens, frozenset({"--where"}))
            toolchain_value = effective_value_flag(tokens, frozenset({"--toolchain"}))
            if not (
                static_nonempty_value(where_value)
                or static_nonempty_value(toolchain_value)
            ):
                return "cub function list cache-write"
            return ""
        if verb == "local":
            filename, filename_index = next_positional(
                tokens, verb_index + 1, CUB_RUN_VALUE_FLAGS
            )
            if not filename and filename_index < len(tokens) and tokens[filename_index] == "--":
                filename_index += 1
                filename = tokens[filename_index] if filename_index < len(tokens) else ""
            function, _ = next_function_name(
                tokens, filename_index + 1, CUB_RUN_VALUE_FLAGS
            )
            if function == "generate-kubecontext":
                return "cub function local generate-kubecontext"
            if function in {"validate", "vet-schemas"}:
                return f"cub function local {function} external-schema-fetch"
            if function not in REVIEWED_LOCAL_CUB_FUNCTIONS:
                return "cub function local unreviewed-function"
            return ""
        if verb in {"set", "exec"}:
            return f"cub function {verb}"
        if verb in {"do", "get", "vet"}:
            label = f"cub function {verb}"
            composed = composed_function_effect(tokens, label)
            if composed:
                return composed
            function, _ = next_function_name(tokens, verb_index + 1, CUB_RUN_VALUE_FLAGS)
            if function in READ_ONLY_CUB_RUN_FUNCTIONS:
                scope_effect = bounded_space_effect(tokens, label)
                if scope_effect:
                    return scope_effect
                if verb in {"get", "vet"}:
                    return f"{label} cache-refresh"
                return ""
            return f"{label} {function}".rstrip()
        return ""
    if noun == "upgrade":
        return "cub upgrade"
    if noun == "auth":
        verb, _ = next_positional(tokens, noun_index + 1, CUB_VALUE_FLAGS)
        return f"cub auth {verb}" if verb in AUTH_SENSITIVE_VERBS else ""
    if noun == "context":
        verb, _ = next_positional(tokens, noun_index + 1, CUB_VALUE_FLAGS)
        if verb not in CONTEXT_MUTATION_VERBS:
            return ""
        return "cub context use" if verb == "set-current" else f"cub context {verb}"
    if noun == "plugin":
        verb, _ = next_positional(tokens, noun_index + 1, CUB_VALUE_FLAGS)
        return f"cub plugin {verb}" if verb in PLUGIN_LIFECYCLE_VERBS else ""
    if noun == "k8s":
        verb, _ = next_positional(tokens, noun_index + 1, CUB_VALUE_FLAGS)
        if verb in {"collect", "refresh"}:
            # Both leaves can write ConfigHub state. Keep their dry-run forms
            # stopped too: this source-level hook cannot authenticate the cub
            # binary/server pair or guarantee redaction of live-object drift,
            # and Cobra can consume an apparent boolean token as another
            # option's string value. #996 owns any future exact-profile read
            # exemption.
            return f"cub k8s {verb}"
        return ""
    if noun == "invocation":
        verb, verb_index = next_positional(tokens, noun_index + 1, CUB_VALUE_FLAGS)
        if verb == "invoke":
            operation, _ = next_positional(tokens, verb_index + 1, CUB_VALUE_FLAGS)
            if operation == "set":
                return "cub invocation invoke set"
            if operation in {"get", "vet"}:
                label = f"cub invocation invoke {operation}"
                composed = composed_function_effect(tokens, label)
                if composed:
                    return composed
                # The stored Invocation's function, worker, arguments and
                # mutable cached kind are not bound by this argv. Even a `get`
                # record can therefore execute credential-producing or
                # worker-provided behavior that static classification cannot
                # authenticate.
                return label
            return ""
    if noun == "target":
        verb, _ = next_positional(tokens, noun_index + 1, CUB_VALUE_FLAGS)
        if verb == "access":
            return "cub target access"
    if noun == "worker":
        verb, _ = next_positional(tokens, noun_index + 1, CUB_VALUE_FLAGS)
        if verb == "status":
            # Despite its name, the pinned clients delete stale local PID
            # files while reporting status.
            return "cub worker status stale-pid-cleanup"
        if verb in WORKER_CREDENTIAL_VERBS:
            return f"cub worker {verb}"
        if verb == "install":
            if any(
                boolean_flag_enabled(tokens, flag)
                for flag in ("--include-secret", "--export-secret-only")
            ):
                return "cub worker install credential-export"
        if verb == "get":
            if boolean_flag_enabled(tokens, "--include-secret"):
                return "cub worker get --include-secret"
        # A raw remote --dry-run is not a safety exemption. The hook cannot
        # authenticate the Cub executable or prove the contacted server honors
        # the reviewed client source semantics, so upgrade falls through to the
        # generic governed-mutation classifier below.
    if noun not in {"unit", "gitops", "oauthclient", "release", "variant"}:
        verb, _ = next_positional(tokens, noun_index + 1, CUB_VALUE_FLAGS)
        if noun in CUB_GENERIC_ENTITY_NOUNS and verb in CUB_ENTITY_MUTATION_VERBS:
            return f"cub {noun} {verb}"
        if (
            noun in CUB_GENERIC_ENTITY_NOUNS
            and verb
            and verb not in REVIEWED_GENERIC_ENTITY_READ_VERBS
        ):
            return f"cub {noun} unreviewed-operation"
        return ""
    verb, _ = next_positional(tokens, noun_index + 1, CUB_VALUE_FLAGS)
    if noun == "unit" and verb == "conflicts":
        # Bare `cub unit conflicts` lists what the last merge withheld. That is a
        # read, and the one we most want a user doing before they promote, so it
        # stays free. `--apply` replays the withheld changes and `--dismiss` drops
        # them; both write.
        for flag in sorted(CONFLICT_MUTATION_FLAGS):
            if boolean_flag_enabled(tokens, flag):
                return f"cub unit conflicts {flag[2:]}"
        return ""
    if noun == "unit" and verb in UNIT_MUTATION_VERBS:
        # Keep remote update governed even with a literal --dry-run: neither the
        # executable bytes nor the server's interpretation are authenticated by
        # this source-level hook.
        return f"cub unit {verb}"
    if noun == "gitops" and verb in GITOPS_MUTATION_VERBS:
        return f"cub gitops {verb}"
    if noun == "oauthclient" and verb in OAUTHCLIENT_MUTATION_VERBS:
        return f"cub oauthclient {verb}"
    if noun == "release" and verb in RELEASE_MUTATION_VERBS:
        return f"cub release {verb}"
    if noun == "variant" and verb in VARIANT_MUTATION_VERBS:
        # Promote/upload dry-runs cross the same unauthenticated remote boundary
        # as their write forms and therefore remain governed raw operations.
        return f"cub variant {verb}"
    return ""


def protected_kubectl(tokens: list[str], expansion_flags: list[bool]) -> str:
    control_end = tokens.index("--") if "--" in tokens else len(tokens)
    if any(expansion_flags[:control_end]):
        return "kubectl <dynamic-argument>"
    verb, verb_index = next_positional(tokens, 0, KUBECTL_GLOBAL_VALUE_FLAGS)
    if verb and verb not in REVIEWED_KUBECTL_NOUNS:
        # Kubectl dispatches an unknown root word to a same-named executable on
        # PATH. Its bytes and inherited credentials are outside this review.
        return "kubectl unreviewed-plugin-or-root"
    profile = effective_value_flag(tokens, frozenset({"--profile"})).strip().lower()
    if profile and profile != "none":
        return "kubectl --profile local-write"
    if verb in KUBECTL_MUTATION_VERBS:
        return f"kubectl {verb}"
    if verb in {"attach", "port-forward", "proxy"}:
        return f"kubectl {verb}"
    if verb == "diff":
        # Kubectl executes KUBECTL_EXTERNAL_DIFF from the ambient environment;
        # --show-secrets can additionally disclose Secret values.
        return "kubectl diff external-executable"
    if verb == "kustomize":
        # This surface can execute filesystem plugins, Helm, and containerized
        # functions and can write arbitrary output paths. A safe literal carveout
        # needs an authenticated input/runtime contract that the hook lacks.
        return "kubectl kustomize unreviewed-execution"
    if verb == "cluster-info":
        operation, operation_index = next_positional(
            tokens, verb_index + 1, KUBECTL_GLOBAL_VALUE_FLAGS
        )
        if operation == "dump":
            output_dir = effective_value_flag(
                tokens, frozenset({"--output-directory"})
            )
            if output_dir not in {"", "-"}:
                return "kubectl cluster-info dump --output-directory"
    if verb == "kuberc":
        # `set` writes preferences directly; `view` can interactively create
        # the default file when it is absent. Keep the whole root governed.
        return "kubectl kuberc local-write"
    if verb == "config":
        operation, _ = next_positional(
            tokens, verb_index + 1, KUBECTL_GLOBAL_VALUE_FLAGS
        )
        if operation == "view" and (
            boolean_flag_enabled(tokens, "--raw")
            or boolean_flag_enabled(tokens, "--flatten")
        ):
            return "kubectl config view credential-disclosure"
        if operation in {
            "delete-cluster",
            "delete-context",
            "delete-user",
            "rename-context",
            "set",
            "set-cluster",
            "set-context",
            "set-credentials",
            "unset",
            "use-context",
        }:
            return f"kubectl config {operation}"
        return ""
    if verb == "get":
        if value_flag_present(tokens, "--raw"):
            return "kubectl get --raw"
        resource, _ = next_positional(
            tokens, verb_index + 1, KUBECTL_GET_VALUE_FLAGS
        )
        resource_kinds = {
            member.split("/", 1)[0].split(".", 1)[0].lower()
            for member in resource.split(",")
            if member
        }
        if resource_kinds & {"secret", "secrets"}:
            return "kubectl get secret"
    if verb == "describe":
        resource, _ = next_positional(
            tokens, verb_index + 1, KUBECTL_DESCRIBE_VALUE_FLAGS
        )
        resource_kinds = {
            member.split("/", 1)[0].split(".", 1)[0].lower()
            for member in resource.split(",")
            if member
        }
        if resource_kinds & {"secret", "secrets"}:
            return "kubectl describe secret"
    if verb == "certificate":
        certificate_verb, _ = next_positional(tokens, verb_index + 1, KUBECTL_GLOBAL_VALUE_FLAGS)
        if certificate_verb in {"approve", "deny"}:
            return f"kubectl certificate {certificate_verb}"
        return ""
    if verb == "auth":
        auth_verb, _ = next_positional(tokens, verb_index + 1, KUBECTL_GLOBAL_VALUE_FLAGS)
        return "kubectl auth reconcile" if auth_verb == "reconcile" else ""
    if verb != "rollout":
        return ""
    rollout_verb, _ = next_positional(tokens, verb_index + 1, KUBECTL_GLOBAL_VALUE_FLAGS)
    if rollout_verb in {"pause", "restart", "resume", "undo"}:
        return f"kubectl rollout {rollout_verb}"
    return ""


def nested_shell_command(tokens: list[str]) -> str:
    """Return a script evaluated by a common shell wrapper, when present."""
    executable = basename(tokens[0])
    if executable == "eval":
        start = 2 if tokens[1:2] == ["--"] else 1
        return " ".join(tokens[start:])
    if executable not in SHELL_EXECUTABLES:
        return ""

    for index, token in enumerate(tokens[1:], start=1):
        if token == "--command" and index + 1 < len(tokens):
            return tokens[index + 1]
        if token.startswith("--command="):
            return token.split("=", 1)[1]
        if token == "-c" and index + 1 < len(tokens):
            return tokens[index + 1]
        if token.startswith("-") and not token.startswith("--") and "c" in token[1:] and index + 1 < len(tokens):
            return tokens[index + 1]
    return ""


def protected_command(
    command: str,
    depth: int = 0,
    classify_any_provider: bool = False,
    *,
    allow_reviewed_unit_projection: bool = False,
) -> str:
    """Find a protected provider write in a directly- or shell-executed form.

    A protected write is flagged only when it is actually the command executed
    by THIS clause:

      * a direct `cub`/`kubectl` mutation (`cub unit apply ...`);
      * a genuinely-executed nested shell wrapper (`bash -c '...'`, `sh -c`,
        `eval`, `env -S ...`), whose script is recursed into; or
      * every command or process substitution, because Bash executes those
        bodies before passing their output/path as argument or assignment data;
      * substitutions in an unquoted heredoc (quoted delimiters stay literal);
      * a statically visible shell-function body that is invoked later in the
        same tool call; or
      * a command word assembled by a substitution followed by a governed Cub
        noun/verb, which fails closed as a dynamic governed route.

    Literal protected phrases remain safe inside single quotes, printf data,
    comments, and heredocs whose delimiters are quoted. Shell parsing is only a
    defense-in-depth UX guard, never an authorization boundary: production
    safety still requires credentials unavailable to the raw assistant shell
    and provider-side authorization of the exact approved operation.
    """
    if PILOT_ACTIVE and not ADDON_EXECUTABLE_INVENTORY_VALID:
        # Missing, malformed, substituted, or digest-mismatched policy must not
        # silently drop a reviewed non-prefixed alias. Stop every active Bash
        # request until the exact adjacent packaged inventory is restored.
        return INVALID_ADDON_EXECUTABLE_INVENTORY
    if depth > 4:
        # A syntactically valid chain deeper than the reviewed recursion bound
        # is unresolved execution, never evidence that the eventual command is
        # harmless.
        return "provider <dynamic-command>"
    clauses = split_shell_clauses(command)
    # Substitutions execute regardless of whether their result becomes a
    # command word, an argument, a filename, or an assignment value. Scan the
    # parsed clauses so quoted-heredoc bodies are not mistaken for shell code;
    # expansion-enabled heredocs are handled explicitly below.
    for clause in clauses:
        for body in command_substitutions(clause):
            protected = protected_command(body, depth + 1, classify_any_provider)
            if protected:
                return protected
        for body in process_substitutions(clause):
            protected = protected_command(body, depth + 1, classify_any_provider)
            if protected:
                return protected
    for heredoc_body in expanded_heredoc_bodies(command):
        for body in command_substitutions(heredoc_body):
            protected = protected_command(body, depth + 1, classify_any_provider)
            if protected:
                return protected
        for body in process_substitutions(heredoc_body):
            protected = protected_command(body, depth + 1, classify_any_provider)
            if protected:
                return protected
    for body in invoked_function_bodies(command):
        protected = protected_command(body, depth + 1, classify_any_provider)
        if protected:
            return protected
    for clause in clauses:
        dynamic_route = dynamic_leading_protected_route(clause)
        if dynamic_route and (PILOT_ACTIVE or dynamic_route == DYNAMIC_LOCAL_KIND_LIFECYCLE):
            return dynamic_route
        token_clause = normalize_terminal_compound_grouping(clause)
        raw_tokens, raw_expansion = tokens_with_expansion(token_clause)
        if shell_command_lookup_only(raw_tokens):
            # `command -v/-V` asks the shell how a name would resolve; it does
            # not invoke the named executable. Preserve that bounded local read
            # even when the queried name is a protected add-on basename.
            continue
        tokens, expansion_flags = command_tokens_with_expansion(
            raw_tokens, raw_expansion
        )
        tokens, expansion_flags = compound_command_payload(
            tokens, expansion_flags
        )
        if tokens and expansion_flags[0]:
            # Bodies were scanned above, but their stdout remains an unknown
            # executable name. Do not infer that it is a harmless provider.
            return "provider <dynamic-command>"
        if not tokens:
            continue
        if approved_execution(tokens):
            if classify_any_provider:
                return "provider <dynamic-command>"
            continue
        executable = basename(tokens[0])
        standalone_addon = protected_standalone_cub_addon(executable)
        if standalone_addon:
            return standalone_addon
        if executable in UNREVIEWED_EXECUTION_WRAPPERS:
            payloads, unresolved = wrapped_command_payloads(tokens, expansion_flags)
            if unresolved:
                return "provider <dynamic-command>"
            for payload_tokens, payload_flags, runtime_dynamic in payloads:
                normalized, normalized_flags = command_tokens_with_expansion(
                    payload_tokens, payload_flags
                )
                normalized, normalized_flags = compound_command_payload(
                    normalized, normalized_flags
                )
                if normalized and normalized_flags[0]:
                    return "provider <dynamic-command>"
                nested = shlex.join(payload_tokens)
                protected = protected_command(
                    nested,
                    depth,
                    classify_any_provider
                    or runtime_dynamic
                    or any(payload_flags),
                )
                if protected:
                    return protected
            continue
        pre_help_protected = ""
        literal_help = False
        if executable == "cub":
            pre_help_protected = protected_cub(
                tokens[1:],
                expansion_flags[1:],
                allow_reviewed_unit_projection=allow_reviewed_unit_projection,
            )
            literal_help = reviewed_literal_core_cub_help(tokens[1:])
        elif executable == "kubectl":
            pre_help_protected = protected_kubectl(
                tokens[1:], expansion_flags[1:]
            )
            literal_help = reviewed_literal_kubectl_help(tokens[1:])
        elif executable == "kind":
            pre_help_protected = protected_kind(tokens[1:], expansion_flags[1:])
            literal_help = reviewed_literal_kind_help(tokens[1:])
        else:
            pre_help_protected = protected_pilot_local_kind(tokens, expansion_flags)
            literal_help = reviewed_literal_pilot_local_kind_help(tokens)
        if pre_help_protected:
            # Classify every protected provider effect before the global help
            # shortcut. Cobra-style parsers may consume a later `--help` token
            # as the value of a preceding string option, so token presence
            # alone cannot prove that help is effective.
            if not any(expansion_flags) and literal_help:
                if classify_any_provider:
                    return "provider <dynamic-command>"
                continue
            return pre_help_protected
        if is_help(tokens):
            if executable == "kubectl":
                # Kubectl resolves an unknown root noun to `kubectl-<noun>`
                # before Cobra handles `--help`. Plugin argv must begin with
                # the noun; a leading flag makes kubectl reject plugin lookup.
                help_noun = (
                    tokens[1]
                    if len(tokens) > 1 and not tokens[1].startswith("-")
                    else ""
                )
                if help_noun and help_noun not in REVIEWED_KUBECTL_NOUNS:
                    return "kubectl unreviewed-plugin-or-root"
                if classify_any_provider:
                    return "provider <dynamic-command>"
                continue
            if executable != "cub":
                if classify_any_provider and executable in VISIBLE_PROVIDER_EXECUTABLES:
                    return "provider <dynamic-command>"
                continue
            help_noun, _ = next_positional(tokens[1:], 0, CUB_VALUE_FLAGS)
            if help_noun in REVIEWED_CORE_CUB_NOUNS or help_noun in {"", "docgen"}:
                if classify_any_provider:
                    return "provider <dynamic-command>"
                continue
            # Installed plugins receive CUB_TOKEN even for their `--help` path.
            if help_noun == "helm":
                protected = "cub helm plugin-execution"
            elif help_noun == "lk":
                protected = "cub lk plugin-execution"
            elif help_noun == "gitops":
                protected = "cub gitops plugin-execution"
            elif help_noun == SCOUT_PLUGIN_NOUN:
                protected = ""
            else:
                protected = "cub unreviewed-plugin-or-root"
            return protected
        if executable == "cub":
            protected = protected_cub(
                tokens[1:],
                expansion_flags[1:],
                allow_reviewed_unit_projection=allow_reviewed_unit_projection,
            )
        elif executable == "kind":
            protected = protected_kind(tokens[1:], expansion_flags[1:])
        elif protected_pilot_local_kind(tokens, expansion_flags):
            protected = protected_pilot_local_kind(tokens, expansion_flags)
        elif executable == "kubectl":
            protected = protected_kubectl(tokens[1:], expansion_flags[1:])
        else:
            # Substitutions were scanned before token classification. Follow
            # any genuinely executed nested shell script as well.
            nested = nested_shell_command(tokens)
            protected = (
                protected_command(nested, depth + 1, classify_any_provider)
                if nested
                else ""
            )
        if protected:
            return protected
        if classify_any_provider and executable in VISIBLE_PROVIDER_EXECUTABLES:
            return "provider <dynamic-command>"
    return ""


INTERACTIVE_UNIT_VERBS = frozenset({
    # "approve" was the exact-revision interactive Unit approval lane; v0.5.7
    # removes it from that role (docs/engineering/OPERATIONAL_INVARIANTS.md, "cub unit
    # approve" is removed once the Attestation model ships). `cub unit
    # approve` now always refuses (see the "cub unit approve" branch below);
    # `cub variant approve` and `cub attestation create` are the interactive
    # lanes for recording an approval attestation.
    "tag",
    "update",
})
INTERACTIVE_DISALLOWED_FLAGS = frozenset({
    "--dest-space",
    "--filename",
    "--filter",
    "--from-downstream-where",
    "--from-stdin",
    "--invocation",
    "--link",
    "--name-pattern",
    "--name-prefix",
    "--output-file",
    "--permission",
    "--replace",
    "--reverse",
    "--set-context",
    "--to-downstream-where",
    "--trigger",
    "--unit",
    "--where",
    "--where-data",
    "--where-resource",
    "--where-space",
    "--worker",
    "-O",
})


def flag_is_present(tokens: list[str], flag: str) -> bool:
    """Recognize one literal long/short option before Cub's separator."""
    for token in tokens:
        if token == "--":
            break
        if token == flag or token.startswith(flag + "="):
            return True
        if (
            len(flag) == 2
            and flag.startswith("-")
            and not flag.startswith("--")
            and token.startswith(flag)
            and len(token) > 2
        ):
            return True
    return False


def single_literal_flag_value(tokens: list[str], flag: str) -> str:
    values = flag_values(tokens, flag)
    if len(values) != 1 or not static_nonempty_value(values[0]):
        return ""
    return values[0]


def direct_literal_executable_tokens(command: str, executable: str) -> list[str]:
    """Return argv only for one direct call to `executable` with no shell control.

    `ask` causes the complete Bash payload to run when the host permits it, so
    the exemption must apply to the payload, not merely to the first protected
    clause found inside it. Wrappers, assignments, substitutions, pipelines,
    lists, redirections, background jobs, and compound commands stay outside
    this lane even when their eventual argv looks harmless.
    """
    # Host review must not be visually spoofable. Interactive argv therefore
    # excludes every C0/DEL byte and Unicode format control (including bidi
    # overrides/isolates and zero-width controls), even inside quotes.
    if any(ord(char) < 32 or ord(char) == 127 for char in command):
        return []
    if any(unicodedata.category(char) == "Cf" for char in command):
        return []
    clauses = split_shell_clauses(command)
    if len(clauses) != 1:
        return []
    clause = clauses[0]
    # Require the raw first token itself to be the executable's literal bytes.
    # Python shlex normalizes c\ub, c""ub, and 'cub' to the same argv, but the
    # host shows source text and must not be asked to approve an obfuscated
    # executable. PATH remains mutable; binary attestation is a future layer.
    raw_clause = clause.lstrip(" ")
    if not re.match(rf"^{re.escape(executable)}(?: +|$)", raw_clause):
        return []
    if REDIRECTION_SENTINEL in redirection_marked_source(clause):
        return []
    tokens, expansion_flags = tokens_with_expansion(clause)
    if not tokens or any(expansion_flags):
        return []
    if tokens[0] != executable:
        return []
    return tokens


def direct_literal_cub_tokens(command: str) -> list[str]:
    """Return argv only for one direct Cub call with no shell control."""
    return direct_literal_executable_tokens(command, "cub")


def direct_literal_kind_tokens(command: str) -> list[str]:
    """Return argv only for one direct kind call with no shell control."""
    return direct_literal_executable_tokens(command, "kind")


def exact_direct_object(
    tokens: list[str], start: int, value_flags: frozenset[str]
) -> str:
    """Find one literal object while accepting only reviewed leading flags."""
    value, _ = next_positional(tokens, start, value_flags)
    return value if static_cub_identifier(value) else ""


def reviewed_literal_argv(
    tokens: list[str],
    *,
    value_flags: frozenset[str],
    boolean_flags: frozenset[str] = frozenset(),
) -> tuple[list[str], dict[str, list[str]]] | None:
    """Parse one deliberately tiny literal argv grammar.

    Every option must be enumerated, every value option must have one literal
    value, and no option may repeat. This avoids Cobra's last-one-wins and
    StringSlice append behavior changing scope or effect after review.
    """
    positionals: list[str] = []
    values: dict[str, list[str]] = {}
    index = 0
    while index < len(tokens):
        token = tokens[index]
        if token == "--":
            return None
        if token.startswith("--"):
            name, separator, attached = token.partition("=")
            if name in value_flags:
                if separator:
                    value = attached
                    index += 1
                else:
                    if index + 1 >= len(tokens):
                        return None
                    value = tokens[index + 1]
                    index += 2
                if not static_nonempty_value(value):
                    return None
                values.setdefault(name, []).append(value)
                continue
            if name in boolean_flags:
                if separator and attached.lower() not in TRUE_FLAG_VALUES:
                    return None
                values.setdefault(name, []).append(attached or "true")
                index += 1
                continue
            return None
        if token.startswith("-"):
            # Short options, stdin markers, and negative relative revisions
            # are outside this literal single-effect grammar.
            return None
        positionals.append(token)
        index += 1
    if any(len(items) != 1 for items in values.values()):
        return None
    return positionals, values


def one_reviewed_value(values: dict[str, list[str]], name: str) -> str:
    items = values.get(name, [])
    return items[0] if len(items) == 1 else ""


def reviewed_literal_core_cub_help(tokens: list[str]) -> bool:
    """Recognize core Cub help only when the boolean cannot be option data."""
    normalized = ["--help" if token == "-h" else token for token in tokens]
    parsed = reviewed_literal_argv(
        ["cub", *normalized],
        value_flags=frozenset({"--context"}),
        boolean_flags=frozenset({"--help"}),
    )
    if parsed is None:
        return False
    positionals, values = parsed
    if len(positionals) < 2 or positionals[0] != "cub":
        return False
    noun = positionals[1]
    if noun not in REVIEWED_CORE_CUB_NOUNS and noun != "docgen":
        return False
    context = one_reviewed_value(values, "--context")
    return (
        all(static_nonempty_value(item) for item in positionals)
        and (not context or static_cub_identifier(context))
        and one_reviewed_value(values, "--help").lower() in TRUE_FLAG_VALUES
    )


def reviewed_literal_kubectl_help(tokens: list[str]) -> bool:
    """Recognize literal kubectl help without trusting a consumed flag token."""
    normalized = ["--help" if token == "-h" else token for token in tokens]
    parsed = reviewed_literal_argv(
        ["kubectl", *normalized],
        value_flags=frozenset(),
        boolean_flags=frozenset({"--help"}),
    )
    if parsed is None:
        return False
    positionals, values = parsed
    if (
        len(positionals) < 2
        or positionals[0] != "kubectl"
        or one_reviewed_value(values, "--help").lower() not in TRUE_FLAG_VALUES
        or not all(static_nonempty_value(item) for item in positionals)
    ):
        return False
    root_help_first = bool(normalized) and (
        normalized[0] == "--help" or normalized[0].startswith("--help=")
    )
    return root_help_first or positionals[1] in REVIEWED_KUBECTL_NOUNS


def reviewed_literal_kind_help(tokens: list[str]) -> bool:
    """Recognize only bare kind cluster lifecycle help."""
    normalized = ["--help" if token == "-h" else token for token in tokens]
    parsed = reviewed_literal_argv(
        ["kind", *normalized],
        value_flags=frozenset(),
        boolean_flags=frozenset({"--help"}),
    )
    if parsed is None:
        return False
    positionals, values = parsed
    return (
        len(positionals) >= 3
        and positionals[:1] == ["kind"]
        and positionals[1] in {"create", "delete"}
        and positionals[2] == "cluster"
        and all(static_nonempty_value(item) for item in positionals)
        and one_reviewed_value(values, "--help").lower() in TRUE_FLAG_VALUES
    )


def reviewed_literal_pilot_local_kind_help(tokens: list[str]) -> bool:
    """Recognize strict help for each governed local-kind entrypoint.

    The live route remains protected before the general help shortcut because
    a later ``--help`` token may be consumed as option data.  This exemption
    therefore admits only the literal checkout/installed Pilot dispatch,
    direct helper, and unflagged Python-wrapper shapes, with no value options
    and no repeated booleans.
    """
    if not tokens:
        return False
    normalized = ["--help" if token == "-h" else token for token in tokens]
    if any(
        token.startswith(("--help=", "--live-kind=", "--quiet="))
        for token in normalized
    ):
        # These entrypoints use argparse store_true flags, not Cobra booleans.
        # Attached truthy values therefore exit with a parse error instead of
        # rendering help and cannot qualify for the literal-help exemption.
        return False
    executable = basename(normalized[0])
    if re.fullmatch(r"python(?:\d+(?:\.\d+)*)?", executable):
        if len(normalized) < 2 or normalized[1].startswith("-"):
            return False
        normalized = normalized[1:]
        executable = basename(normalized[0])
    if executable == "pilot":
        dispatcher_tail = normalized[1:]
        if dispatcher_tail[:1] == ["--quiet"]:
            dispatcher_tail = dispatcher_tail[1:]
        if dispatcher_tail[:1] != ["local-kind-live-proof"]:
            return False
        if "--quiet" in dispatcher_tail[1:]:
            return False
    parsed = reviewed_literal_argv(
        [executable, *normalized[1:]],
        value_flags=frozenset(),
        boolean_flags=frozenset({"--help", "--live-kind", "--quiet"}),
    )
    if parsed is None:
        return False
    positionals, values = parsed
    if executable == "pilot":
        if positionals != ["pilot", "local-kind-live-proof"]:
            return False
    elif executable == "pilot-local-kind-live-proof":
        if positionals != ["pilot-local-kind-live-proof"] or "--quiet" in values:
            return False
    else:
        return False
    return (
        one_reviewed_value(values, "--help").lower() in TRUE_FLAG_VALUES
        and one_reviewed_value(values, "--live-kind").lower()
        in TRUE_FLAG_VALUES
    )


def exact_revision_reference(value: str) -> bool:
    """Accept an immutable positive revision number or UUID, not a pointer."""
    if value.isdigit():
        return int(value) > 0
    return bool(
        re.fullmatch(
            r"[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-"
            r"[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}",
            value,
        )
    )


def change_description_note(values: dict[str, list[str]]) -> str:
    """Show a reviewed ``--change-desc`` value in the scope summary.

    The value is already one literal with no ``$`` or backtick. It is shown
    as one quoted string so text inside it cannot pass for Pilot's own words.
    """
    text = one_reviewed_value(values, "--change-desc")
    if not text:
        return ""
    return f" with change description {json.dumps(text, ensure_ascii=False)}"


# The reviewed forms a refusal can print. These only word a refusal: the
# grammar that admits a command is each branch of `interactive_cub_scope`.
REVIEWED_INTERACTIVE_FORMS = {
    ("function", "set"): {
        "form": (
            "cub function set <function> <value> --space <space> --unit <unit> "
            "[--change-desc <text>] --context <context>"
        ),
        "value_flags": ("--change-desc", "--context", "--space", "--unit"),
        "required": ("--context", "--space", "--unit"),
        "names": ("--context", "--space", "--unit"),
    },
    ("function", "do"): {
        "form": (
            "cub function do <function> <value> --space <space> --unit <unit> "
            "[--change-desc <text>] --context <context>"
        ),
        "value_flags": ("--change-desc", "--context", "--space", "--unit"),
        "required": ("--context", "--space", "--unit"),
        "names": ("--context", "--space", "--unit"),
    },
    ("variant", "promote"): {
        "form": "cub variant promote <space> [--change-desc <text>] --context <context>",
        "value_flags": ("--change-desc", "--context"),
        "required": ("--context",),
        "names": ("--context",),
    },
    ("release", "publish"): {
        "form": "cub release publish <space> [--revision <tag>] --context <context>",
        "value_flags": ("--context", "--revision"),
        "required": ("--context",),
        "names": ("--context",),
    },
}
# Mirrors `expected_arguments` in the `function set|do` branch of
# `interactive_cub_scope`, which is the grammar that decides.
INTERACTIVE_FUNCTION_ARGUMENT_COUNTS = {
    "set-container-image": 2,
    "set-image": 2,
    "set-namespace": 1,
    "set-replicas": 1,
}


def reviewed_form_family(protected: str) -> tuple[str, str] | None:
    """Name the reviewed form a stopped classification belongs to, if any."""
    if protected == "cub function set":
        return ("function", "set")
    if protected == "cub function do" or (
        protected.startswith("cub function do ")
        and protected != "cub function do generate-kubecontext"
    ):
        # The credential-producing function keeps its own credential stop.
        return ("function", "do")
    if protected == "cub variant promote":
        return ("variant", "promote")
    if protected == "cub release publish":
        return ("release", "publish")
    return None


def plain_option_list(names: list[str]) -> str:
    """Join option names for a sentence, hiding any that are not plain."""
    shown = [
        f"`{name}`"
        if re.fullmatch(r"--?[A-Za-z0-9][A-Za-z0-9-]*", name)
        else "an option Pilot does not recognise"
        for name in names
    ]
    shown = list(dict.fromkeys(shown))
    if len(shown) <= 1:
        return "".join(shown)
    return ", ".join(shown[:-1]) + " and " + shown[-1]


def reviewed_form_guidance(tokens: list[str], protected: str) -> str:
    """Say how one direct literal command misses its reviewed form.

    This only words a refusal that has already been decided. It admits
    nothing: a command reaches it because `interactive_cub_scope` returned
    no scope for it.
    """
    family = reviewed_form_family(protected)
    if not tokens or family is None:
        return ""
    noun, noun_index = next_positional(tokens, 1, CUB_VALUE_FLAGS)
    verb, _verb_index = next_positional(tokens, noun_index + 1, CUB_VALUE_FLAGS)
    written_verb = verb
    if noun == "function" and verb == "invoke":
        verb = "do"
    if (noun, verb) != family:
        return ""
    spec = REVIEWED_INTERACTIVE_FORMS[family]
    seen: dict[str, list[str]] = {}
    outside: list[str] = []
    positionals: list[str] = []
    separator = False
    index = 1
    while index < len(tokens):
        token = tokens[index]
        if token == "--":
            separator = True
            break
        if token.startswith("--"):
            name, attached_separator, attached = token.partition("=")
            if name in spec["value_flags"]:
                if attached_separator:
                    value = attached
                    index += 1
                else:
                    value = tokens[index + 1] if index + 1 < len(tokens) else ""
                    index += 2
                seen.setdefault(name, []).append(value)
                continue
            outside.append(name)
            index += 1
            continue
        if token.startswith("-"):
            outside.append(token if len(token) <= 2 else token[:2])
            index += 1
            continue
        positionals.append(token)
        index += 1

    problems: list[str] = []
    if outside:
        problems.append(
            f"This command also carries {plain_option_list(outside)}, which "
            f"{'is' if len(dict.fromkeys(outside)) == 1 else 'are'} outside that form."
        )
    if separator:
        problems.append("It uses a `--` separator, which is outside that form.")
    repeated = [name for name, items in seen.items() if len(items) > 1]
    if repeated:
        problems.append(
            f"It gives {plain_option_list(repeated)} more than once; that form "
            "takes each option once."
        )
    missing = [name for name in spec["required"] if name not in seen]
    if missing:
        problems.append(f"It has no {plain_option_list(missing)}.")
    unclear = [
        name
        for name, items in seen.items()
        if len(items) == 1
        and not (
            exact_cub_space(items[0])
            if name in spec["names"]
            else static_nonempty_value(items[0])
        )
    ]
    if unclear:
        problems.append(
            f"The value of {plain_option_list(unclear)} must be one plain literal: "
            "one exact name or text, with no wildcard, list, `$`, or backtick."
        )
    # An option outside the form may or may not take the next word as its
    # value, so the remaining words are only checked when every option is known.
    if not outside and not separator:
        if written_verb == "invoke":
            problems.append("It says `invoke`; that form says `do`.")
        if noun == "function":
            function = positionals[2] if len(positionals) > 2 else ""
            arguments = positionals[3:]
            reviewed_functions = ", ".join(
                f"`{name}`" for name in sorted(INTERACTIVE_MUTATING_FUNCTIONS)
            )
            if function not in INTERACTIVE_MUTATING_FUNCTIONS:
                problems.append(
                    f"That form covers these functions only: {reviewed_functions}."
                )
            elif len(arguments) != INTERACTIVE_FUNCTION_ARGUMENT_COUNTS[function]:
                count = INTERACTIVE_FUNCTION_ARGUMENT_COUNTS[function]
                problems.append(
                    f"`{function}` takes exactly {count} "
                    f"value{'' if count == 1 else 's'} in that form."
                )
            elif not all(static_nonempty_value(value) for value in arguments):
                problems.append(
                    f"The value given to `{function}` must be plain literal text, "
                    "with no `$` or backtick."
                )
            elif function == "set-replicas" and not arguments[0].isdigit():
                problems.append("`set-replicas` takes a whole number of replicas.")
        elif len(positionals) != 3 or not exact_cub_space(positionals[2]):
            problems.append(
                "That form names exactly one Space, with no wildcard and no "
                "second name."
            )
    if not problems:
        problems.append("This command does not match that form exactly.")
    return (
        f"Pilot can ask you to approve `{spec['form']}`. " + " ".join(problems)
    )


def interactive_cub_scope(command: str, protected: str) -> str:
    """Return a human scope summary for the small host-mediated write lane."""
    tokens = direct_literal_cub_tokens(command)
    if not tokens or is_help(tokens):
        return ""
    # Each admitted branch supplies its complete option grammar. Noun/verb
    # extraction is flag-aware only to choose that strict branch.
    noun, noun_index = next_positional(tokens, 1, CUB_VALUE_FLAGS)
    verb, _verb_index = next_positional(tokens, noun_index + 1, CUB_VALUE_FLAGS)

    if noun == "space" and verb in {"create", "update"}:
        parsed = reviewed_literal_argv(
            tokens,
            value_flags=frozenset({"--annotation", "--context", "--label"}),
        )
        if parsed is None:
            return ""
        positionals, values = parsed
        if len(positionals) != 4 or positionals[:3] != ["cub", "space", verb]:
            return ""
        context = one_reviewed_value(values, "--context")
        space = positionals[3]
        if not static_cub_identifier(context) or not exact_cub_space(space):
            return ""
        if verb == "update" and not ({"--annotation", "--label"} & values.keys()):
            return ""
        effect = "create" if verb == "create" else "update metadata on"
        return f"{effect} one Space `{space}` in ConfigHub context `{context}`"

    if noun == "unit" and verb in INTERACTIVE_UNIT_VERBS:
        value_flags_by_verb = {
            "tag": frozenset({"--context", "--revision", "--space", "--unit"}),
            "update": frozenset({"--change-desc", "--context", "--restore", "--space"}),
        }
        parsed = reviewed_literal_argv(
            tokens,
            value_flags=value_flags_by_verb[verb],
        )
        if parsed is None:
            return ""
        positionals, values = parsed
        context = one_reviewed_value(values, "--context")
        space = one_reviewed_value(values, "--space")
        if not static_cub_identifier(context) or not exact_cub_space(space):
            return ""
        if positionals[:3] != ["cub", "unit", verb]:
            return ""
        if verb == "tag":
            if len(positionals) != 4:
                return ""
            tag = positionals[3]
            unit = one_reviewed_value(values, "--unit")
            revision = one_reviewed_value(values, "--revision")
            if (
                not static_cub_identifier(tag)
                or not static_cub_identifier(unit)
                or "," in unit
                or not exact_revision_reference(revision)
            ):
                return ""
            return (
                f"tag exact revision `{revision}` as `{tag}` on Unit "
                f"`{space}/{unit}` in ConfigHub context `{context}`"
            )
        if len(positionals) != 4:
            return ""
        unit = positionals[3]
        if not static_cub_identifier(unit):
            return ""
        # Only "update" (restore) reaches this point now: "approve" left
        # INTERACTIVE_UNIT_VERBS when Pilot moved to the Attestation model.
        revision = one_reviewed_value(values, "--restore")
        if not exact_revision_reference(revision):
            return ""
        return (
            f"restore from exact revision `{revision}` for Unit `{space}/{unit}` "
            f"in ConfigHub context `{context}`"
        )

    if noun == "variant" and verb == "approve":
        # v0.5.7: an approval is an Attestation of type Approval, recorded
        # per Space (docs/engineering/OPERATIONAL_INVARIANTS.md, public/cmd/cub/
        # variant_approve.go). The reviewed literal form binds to exactly
        # one named Space; the multi-space selectors (--change-order,
        # --stage, --where-space) stay outside this lane because they can
        # reach Spaces the reviewer never saw named.
        parsed = reviewed_literal_argv(
            tokens,
            value_flags=frozenset({
                "--context",
                "--evidence",
                "--expires-in",
                "--note",
                "--revision",
                "--where",
            }),
            boolean_flags=frozenset({"--all", "--dry-run", "--no-wait", "--reject"}),
        )
        if parsed is None:
            return ""
        positionals, values = parsed
        if len(positionals) != 4 or positionals[:3] != ["cub", "variant", "approve"]:
            return ""
        context = one_reviewed_value(values, "--context")
        space = positionals[3]
        if not static_cub_identifier(context) or not exact_cub_space(space):
            return ""
        result = "Fail" if "--reject" in values else "Pass"
        return (
            f"record one immutable {result} Approval attestation, covering the "
            f"units of variant Space `{space}`, in ConfigHub context `{context}`. "
            "This does not itself deploy or apply anything -- it is a claim "
            "ConfigHub checks a ChangeWorkflow's attestation prerequisites against"
        )

    if noun == "attestation" and verb == "create":
        # v0.5.7: the general form of recording an attestation, for any
        # Type, not only Approval (docs/engineering/OPERATIONAL_INVARIANTS.md,
        # public/cmd/cub/attestation_create.go). No positional argument:
        # the space and the units within it come from --space and --where.
        parsed = reviewed_literal_argv(
            tokens,
            value_flags=frozenset({
                "--change-order",
                "--claim",
                "--context",
                "--evidence",
                "--expires-in",
                "--note",
                "--revision",
                "--space",
                "--type",
                "--where",
            }),
            boolean_flags=frozenset({"--dry-run", "--reject"}),
        )
        if parsed is None:
            return ""
        positionals, values = parsed
        if positionals != ["cub", "attestation", "create"]:
            return ""
        context = one_reviewed_value(values, "--context")
        space = one_reviewed_value(values, "--space")
        if not static_cub_identifier(context) or not exact_cub_space(space):
            return ""
        attestation_type = one_reviewed_value(values, "--type") or "Approval"
        result = "Fail" if "--reject" in values else "Pass"
        return (
            f"record one immutable {result} `{attestation_type}` attestation -- a "
            f"claim about specific revisions, not a live approval gate by itself "
            f"-- in Space `{space}` in ConfigHub context `{context}`"
        )

    if noun == "attestation" and verb == "revoke":
        # Withdraws an earlier attestation by recording another one that
        # names it; the original record is kept (public/cmd/cub/
        # attestation_revoke.go).
        parsed = reviewed_literal_argv(
            tokens,
            value_flags=frozenset({"--context", "--note", "--space"}),
        )
        if parsed is None:
            return ""
        positionals, values = parsed
        if len(positionals) != 4 or positionals[:3] != ["cub", "attestation", "revoke"]:
            return ""
        context = one_reviewed_value(values, "--context")
        if not static_cub_identifier(context):
            return ""
        attestation_id = positionals[3]
        if not static_cub_identifier(attestation_id):
            return ""
        space = one_reviewed_value(values, "--space")
        space_note = f" held by Space `{space}`" if space else ""
        return (
            f"record a revocation of attestation `{attestation_id}`{space_note} "
            f"in ConfigHub context `{context}`. The original attestation is kept; "
            "this only records that it no longer satisfies requirements"
        )

    if noun == "unit" and verb == "blame":
        # Operator decision 2026-09-23 (#1192): read-only, but it joins current
        # Unit data to mutation, revision, and user history, and by default
        # crosses Space boundaries into upstream Units. Every literal form is
        # host-reviewable; the reach itself is named in the scope summary.
        parsed = reviewed_literal_argv(
            tokens,
            value_flags=frozenset({
                "--context",
                "--output",
                "--path",
                "--resource",
                "--select",
                "--space",
                "--upstream-depth",
            }),
            boolean_flags=frozenset({"--no-upstream", "--show-comments", "--verbose"}),
        )
        if parsed is None:
            return ""
        positionals, values = parsed
        if len(positionals) != 4 or positionals[:3] != ["cub", "unit", "blame"]:
            return ""
        context = one_reviewed_value(values, "--context")
        space = one_reviewed_value(values, "--space")
        if not static_cub_identifier(context) or not exact_cub_space(space):
            return ""
        unit = positionals[3]
        if not static_cub_identifier(unit):
            return ""
        no_upstream = "--no-upstream" in values
        upstream_depth = one_reviewed_value(values, "--upstream-depth")
        if no_upstream:
            reach = "staying on this one Unit only, because `--no-upstream` is set"
        elif upstream_depth:
            if not (upstream_depth.isdigit() and int(upstream_depth) >= 0):
                return ""
            reach = f"following upstream Units across Spaces up to {upstream_depth} level(s)"
        else:
            reach = "following upstream Units across Spaces up to the default depth of 8"
        return (
            f"show the complete current data and change history, including other "
            f"users' changes and values, for Unit `{space}/{unit}` in ConfigHub "
            f"context `{context}`, {reach}"
        )

    if noun == "cluster" and verb in {"up", "down"}:
        # Operator decision 2026-09-23 (#1192): a local kind cluster on this
        # machine is host-reviewable like a bounded ConfigHub mutation.
        # `protected_cub` classifies `--delete-config` separately as a
        # destructive stop before this branch would ever see it.
        value_flags = (
            frozenset({"--argobot-oci", "--context", "--mount", "--name", "--space"})
            if verb == "up"
            else frozenset({"--context", "--name"})
        )
        boolean_flags = (
            frozenset({"--no-argobot", "--no-placeholder-gate", "--no-ports"})
            if verb == "up"
            else frozenset({"--force"})
        )
        parsed = reviewed_literal_argv(
            tokens, value_flags=value_flags, boolean_flags=boolean_flags
        )
        if parsed is None:
            return ""
        positionals, values = parsed
        # cub v0.8.30 takes the cluster name as a positional (`cluster up
        # [<name>]`, `cluster down <name>`); `--name` is hidden but still
        # accepted. Both spellings name the cluster. Giving both is ambiguous
        # (cub rejects it or one wins), so that form is not reviewed here.
        if positionals[:3] != ["cub", "cluster", verb] or len(positionals) > 4:
            return ""
        context = one_reviewed_value(values, "--context")
        if context and not static_cub_identifier(context):
            return ""
        flag_name = one_reviewed_value(values, "--name")
        positional_name = positionals[3] if len(positionals) == 4 else ""
        if flag_name and positional_name:
            return ""
        name = flag_name or positional_name
        if name and not static_cub_identifier(name):
            return ""
        cluster_label = f"`{name}`" if name else "the default-named"
        context_note = f" in ConfigHub context `{context}`" if context else ""
        action = "create" if verb == "up" else "tear down"
        return (
            f"{action} {cluster_label} local kind cluster on this machine"
            f"{context_note}"
        )

    if noun in UNBOUNDED_ORGANIZATION_LIST_NOUNS and verb == "list":
        # Operator decision 2026-09-23 (#1192): Space, Organization,
        # Organization-Member, Component, and User are org-level objects with
        # no narrower scope to bind, so every literal list of them is
        # unscoped by nature. It goes to Claude's host permission with a
        # plain warning instead of a hard stop; Pilot's own automatic
        # discovery still never issues one of these itself.
        parsed = reviewed_literal_argv(
            tokens,
            value_flags=frozenset({
                "--columns",
                "--contains",
                "--context",
                "--filter",
                "--output",
                "--select",
                "--where",
            }),
            boolean_flags=frozenset({"--no-headers", "--quiet", "--verbose"}),
        )
        if parsed is None:
            return ""
        positionals, values = parsed
        if positionals != ["cub", noun, "list"]:
            return ""
        context = one_reviewed_value(values, "--context")
        context_note = f" in ConfigHub context `{context}`" if context else ""
        return (
            f"list every `{noun}` across the whole organization{context_note}; "
            "there is no narrower scope for this object and the result may be large"
        )

    if noun == "cluster" and verb == "list":
        parsed = reviewed_literal_argv(tokens, value_flags=frozenset({"--context"}))
        if parsed is None:
            return ""
        positionals, values = parsed
        if positionals != ["cub", "cluster", "list"]:
            return ""
        context = one_reviewed_value(values, "--context")
        context_note = f" in ConfigHub context `{context}`" if context else ""
        return (
            f"list every local kind cluster this Cub context knows about"
            f"{context_note}; there is no narrower scope for this object"
        )

    if noun == "k8s" and verb in {"get", "types"}:
        parsed = reviewed_literal_argv(
            tokens,
            value_flags=frozenset({
                "--context",
                "--filter",
                "--namespace",
                "--output",
                "--space",
                "--target",
                "--where",
                "--where-resource",
            }),
            boolean_flags=frozenset({"--no-headers", "--quiet", "--verbose"}),
        )
        if parsed is None:
            return ""
        positionals, values = parsed
        if positionals[:3] != ["cub", "k8s", verb]:
            return ""
        space = one_reviewed_value(values, "--space")
        if space != "*":
            # Operator decision 2026-09-23 (#1192) covers only the explicit,
            # affirmative `--space *` wildcard. A missing or ambiguous scope
            # stays a hard stop, because Cub's own ambient context default
            # can silently resolve org-wide without the person asking for it.
            return ""
        context = one_reviewed_value(values, "--context")
        context_note = f" in ConfigHub context `{context}`" if context else ""
        described = "Kubernetes resources" if verb == "get" else "Kubernetes resource types"
        return (
            f"read {described} across every Space in the organization "
            f"(`--space *`){context_note}; the result may be large"
        )

    if noun == "unit" and verb == "tree":
        parsed = reviewed_literal_argv(
            tokens,
            value_flags=frozenset({
                "--columns",
                "--contains",
                "--context",
                "--edge",
                "--filter",
                "--node",
                "--output",
                "--resource-type",
                "--select",
                "--space",
                "--where",
                "--where-data",
            }),
            boolean_flags=frozenset({"--no-headers", "--quiet", "--verbose"}),
        )
        if parsed is None:
            return ""
        positionals, values = parsed
        if positionals != ["cub", "unit", "tree"]:
            return ""
        space = one_reviewed_value(values, "--space")
        if space != "*":
            return ""
        context = one_reviewed_value(values, "--context")
        context_note = f" in ConfigHub context `{context}`" if context else ""
        return (
            "read the Unit dependency tree across every Space in the "
            f"organization (`--space *`){context_note}; the result may be large"
        )

    if noun == "function" and verb in {"set", "do"}:
        # `--change-desc` only labels the revision this one command writes. It
        # takes exactly one literal value and does not change which Unit or
        # function runs, so the form stays one Space, one Unit, one function.
        parsed = reviewed_literal_argv(
            tokens,
            value_flags=frozenset({"--change-desc", "--context", "--space", "--unit"}),
        )
        if parsed is None:
            return ""
        positionals, values = parsed
        if len(positionals) < 5 or positionals[:3] != ["cub", "function", verb]:
            return ""
        context = one_reviewed_value(values, "--context")
        space = one_reviewed_value(values, "--space")
        unit = one_reviewed_value(values, "--unit")
        if not all(static_cub_identifier(value) for value in (context, space, unit)):
            return ""
        function = positionals[3]
        arguments = positionals[4:]
        expected_arguments = {
            "set-container-image": 2,
            "set-image": 2,
            "set-namespace": 1,
            "set-replicas": 1,
        }
        if (
            function not in INTERACTIVE_MUTATING_FUNCTIONS
            or len(arguments) != expected_arguments[function]
            or not all(static_nonempty_value(value) for value in arguments)
        ):
            return ""
        if function == "set-replicas" and not (
            arguments[0].isdigit() and int(arguments[0]) >= 0
        ):
            return ""
        argument_summary = " ".join(f"`{value}`" for value in arguments)
        return (
            f"Unit `{space}/{unit}` via `{function}` with arguments "
            f"{argument_summary} in ConfigHub context `{context}`"
            f"{change_description_note(values)}"
        )

    if noun == "variant" and verb == "promote":
        # `--change-desc` only labels the revisions this promotion writes; the
        # form still names exactly one Space and carries no selector.
        parsed = reviewed_literal_argv(
            tokens,
            value_flags=frozenset({"--change-desc", "--context"}),
        )
        if parsed is None:
            return ""
        positionals, values = parsed
        context = one_reviewed_value(values, "--context")
        if (
            len(positionals) != 4
            or positionals[:3] != ["cub", "variant", "promote"]
            or not static_cub_identifier(context)
            or not exact_cub_space(positionals[3])
        ):
            return ""
        space = positionals[3]
        return (
            f"Space `{space}` in ConfigHub context `{context}`"
            f"{change_description_note(values)}: brings every Unit that is "
            "behind its upstream up to date, adds Units that are new upstream, "
            "and may run stored triggers. On newer ConfigHub versions it can "
            "also replay upstream function runs"
        )

    if noun == "release" and verb == "publish":
        parsed = reviewed_literal_argv(
            tokens,
            value_flags=frozenset({"--context", "--revision"}),
        )
        if parsed is None:
            return ""
        positionals, values = parsed
        context = one_reviewed_value(values, "--context")
        if (
            len(positionals) != 4
            or positionals[:3] != ["cub", "release", "publish"]
            or not static_cub_identifier(context)
        ):
            return ""
        space = positionals[3]
        if not exact_cub_space(space):
            return ""
        if unreviewed_release_boundary_selector(tokens):
            return ""
        revision = one_reviewed_value(values, "--revision")
        revision_note = (
            f"tag `{revision}`; every selected Unit must carry that tag or the "
            "reviewed v0.2.33 implementation aborts publication"
            if revision
            else "each included Unit's current head"
        )
        return (
            f"dynamic whole-Space Release for `{space}` in ConfigHub context "
            f"`{context}`, resolving the current release Target, membership, and "
            f"{revision_note} at execution; this publishes for the configured "
            "Target and may make configuration live when Argo CD, Flux, or another "
            "controller consumes the Release. It does not bind an expected Target "
            "ID, complete membership or manifest, or compare-and-swap Unit heads "
            "and tag mappings, so it is not exact-artifact publication"
        )

    return ""


# --------------------------------------------------------------------------- #
# Operator decision 2026-10-11: reads run, changes ask.
#
# Until then, a command this hook recognised and that was not on the short
# list of reviewed "ask" forms was stopped outright: 134 of the 241 commands
# in cub v0.8.3. The operator asked for that default to go. A recognised
# command now gets one of three answers:
#
#   run   a read. The hook says nothing.
#   ask   everything else. The host shows the exact command and the person
#         allows or declines this one attempt.
#   stop  only what cannot be undone in bulk: deleting a Space with everything
#         in it, deleting an organisation, and `cub cluster down
#         --delete-config`. A broken add-on inventory also still stops.
#
# This is a decision on the label and the command text. It is not a sandbox.
# --------------------------------------------------------------------------- #
RELAXED_KEEP_STOP_LABELS = frozenset(
    {
        "cub cluster down --delete-config",
        "cub cluster detach --delete-config",
        "cub organization delete",
        INVALID_ADDON_EXECUTABLE_INVENTORY,
    }
)
RELAXED_CONFLICTS_WRITE_FLAG = re.compile(r"(?<![\w-])--(?:apply|dismiss)(?![\w-])")
RELAXED_RECURSIVE_FLAG = re.compile(r"(?<![\w-])--recursive(?:-force)?(?![\w-])")
# A flag whose own name contains a variable, such as --"$F".
RELAXED_VARIABLE_IN_FLAG_NAME = re.compile(r"(?<![\w-])--?[\w-]*[\"']?\$")
RELAXED_DRY_RUN_FLAG = re.compile(r"(?<![\w-])--dry-run(?:=(\S*))?(?![\w-])")
RELAXED_READ_VERBS = frozenset(
    {
        "conflicts", "crd-spec", "data", "diff", "explain", "get", "list",
        "list-function", "list-status", "mutation-sources", "tree", "types",
    }
)
# `cub unit blame` is a read, but it shows other people's changes and values
# and follows upstream Units, so it asks in every form (operator decision
# 2026-09-23). It is deliberately not in the set above. `cub variant blame` is
# the same read for a whole variant, and `cub unit path` is its drill-down
# (every change to one field, with who made it), so they ask the same way.
RELAXED_BLAME_LIKE_COMMANDS = frozenset({("unit", "blame"), ("variant", "blame"), ("unit", "path")})
# A service account's secrets: `token create` prints a long-lived bearer token
# once, and `key add` either generates a private key on this machine
# (--generate) or registers a public key. Both are credential work, so both
# ask with the sign-in/tokens/keys sentence, in every form.
RELAXED_CREDENTIAL_MAKING_SERVICEACCOUNT = re.compile(
    r"(?<![\w-])serviceaccount\b[^\n;|&]*?(?<![\w-])(?:token\s+create|key\s+add)(?![\w-])"
)
# A label ending in one of these is a read whose only fault was its output
# format, a local cache refresh, or an older flag spelling.
RELAXED_READ_LABEL_SUFFIXES = (
    " serialized-secret",
    " unreviewed-output-format",
    " version-dependent-output",
)
# Field names that hold a worker's credential. A read that asks for one by
# name is asking to be shown a secret.
RELAXED_SECRET_FIELD = re.compile(r"BridgeWorker|ClaimToken|(?<![A-Za-z])Secret(?![a-z])")
# The command groups built into the newest reviewed cub (v0.8.30). A first word
# outside this list is a separately installed plugin. The hook's older noun
# list predates some of these (changeworkflow, group, and from v0.8.30 apply,
# channel, command, commandrun, review-comment, serviceaccount), and labels
# them as an unreviewed plugin; this list lets a read of a built-in group run,
# and lets the prompt call them built-in groups, not plugins. The approval-hook
# test compares it with the committed capture of that cub.
RELAXED_BUILTIN_CUB_NOUNS = frozenset(
    {
        "api", "apply", "attestation", "attribute", "auth", "changeorder", "changeset",
        "changeworkflow", "channel", "cluster", "command", "commandrun", "completion",
        "component", "context", "filter", "function", "group", "help", "invocation", "k8s",
        "link", "mutation", "oauthclient", "organization", "organization-member", "plugin",
        "release", "resource", "review-comment", "revision", "run", "serviceaccount", "space",
        "tag", "target", "trigger", "unit", "unit-action", "unit-event", "upgrade", "user",
        "variant", "version", "view", "worker",
    }
)
UNREVIEWED_CUB_ROOT_LABEL = "cub unreviewed-plugin-or-root"
# A read with no Space named reaches across the organisation, so it asks.
RELAXED_UNBOUNDED_LABEL_MARKS = (
    "explicit-space-required",
    "bounded-route-required",
    " --space *",
)


def relaxed_cub_words(command: str) -> tuple[str, str, str]:
    """The first three plain words after `cub` in a command, flags skipped."""
    try:
        tokens = shlex.split(command, posix=True)
    except ValueError:
        return "", "", ""
    for index, token in enumerate(tokens):
        if basename(token) != "cub":
            continue
        words: list[str] = []
        cursor = index + 1
        while cursor < len(tokens) and len(words) < 3:
            word = tokens[cursor]
            if word in {"|", "||", "&&", ";", "&"}:
                break
            if word.startswith("-"):
                if "=" not in word and word in CUB_VALUE_FLAGS:
                    cursor += 1
                cursor += 1
                continue
            words.append(word)
            cursor += 1
        words += ["", "", ""]
        return words[0], words[1], words[2]
    return "", "", ""


def relaxed_is_preview(command: str) -> bool:
    """Whether `--dry-run` is in force. The last occurrence decides, as cub does."""
    values = [match.group(1) for match in RELAXED_DRY_RUN_FLAG.finditer(command)]
    if not values:
        return False
    last = values[-1]
    return last is None or last.strip("'\"").lower() == "true"


def relaxed_reveals_secret(protected: str, command: str) -> bool:
    """Whether a read would put a credential in front of the session."""
    if "--include-secret" in command or "--show-secrets" in command:
        return True
    if RELAXED_SECRET_FIELD.search(command) or "generate-kubecontext" in command:
        return True
    if protected.startswith(("cub auth ", "cub api", "cub target access", "cub cluster open")):
        return True
    if RELAXED_CREDENTIAL_MAKING_SERVICEACCOUNT.search(command):
        return True
    if protected.startswith("cub worker ") and (
        " get-secret" in protected
        or " get-envs" in protected
        # A worker read as JSON or YAML carries the worker's own secret.
        or protected.endswith((" serialized-secret", " unreviewed-output-format"))
    ):
        return True
    return any(mark in protected for mark in ("worker-secret-column", "credential", " secret"))


def relaxed_builtin_group_command(command: str, protected: str) -> bool:
    """A built-in cub group that the older noun list labels as a plugin."""
    return protected == UNREVIEWED_CUB_ROOT_LABEL and relaxed_cub_words(command)[0] in RELAXED_BUILTIN_CUB_NOUNS


def relaxed_display_label(protected: str, command: str) -> str:
    """The label a prompt shows. A built-in group the older noun list does not
    know would read `cub unreviewed-plugin-or-root`; show what it is instead."""
    if not relaxed_builtin_group_command(command, protected):
        return protected
    noun, verb, third = relaxed_cub_words(command)
    if noun == "apply" or not re.fullmatch(r"[a-z][a-z-]*", verb):
        return f"cub {noun}"
    if noun == "serviceaccount" and verb in {"key", "token"} and re.fullmatch(r"[a-z][a-z-]*", third):
        return f"cub {noun} {verb} {third}"
    return f"cub {noun} {verb}"


def relaxed_is_read(noun: str, verb: str, third: str) -> bool:
    if noun == "apply":
        # `cub apply` creates, updates and (with --prune) deletes entities
        # from documents. Its arguments are files, so a file named `get` or
        # `list` must not read as a verb.
        return False
    if noun == "serviceaccount" and verb == "token":
        # `token list` shows ids and dates, never the tokens; `token create`
        # prints a token and `token revoke` withdraws one.
        return third == "list"
    if noun in {"auth", "api", "run", "function", "invocation"}:
        # `function list|explain` are reads; `function get|vet|do|set` and
        # `run` execute a function, and `invocation invoke` likewise.
        return noun == "function" and verb in {"list", "explain"}
    if verb == "key":
        return third == "list"
    if verb == "conflicts":
        return third not in {"apply", "dismiss"}
    return verb in RELAXED_READ_VERBS


# kubectl flags whose value only chooses where a read looks: the namespace,
# the cluster context, a label or field selector, or the container. A variable
# here cannot turn a read into a change or into a read of secrets.
RELAXED_KUBECTL_PLACE_FLAGS = frozenset(
    {"-n", "--namespace", "--context", "-l", "--selector", "--field-selector", "-c", "--container"}
)
RELAXED_SHELL_SEPARATORS = frozenset({"|", "||", "&&", ";", "&", "do", "done", "then", "fi"})


def relaxed_kubectl_variable_read(command: str) -> bool:
    """Whether every kubectl in the command is a read whose variables only say
    where to look, such as `for e in dev prod; do kubectl -n shop-$e get pods; done`.

    Each variable must be the value of one of the place flags above. The
    command is then judged as if those values were plain words: it runs only
    if that literal form would run. A variable in the verb, the resource kind
    or any other position still asks, because it could name a secret or a
    change.
    """
    # Split shell operators (`;`, `&&`, `|`, new lines) into their own words,
    # so `get pods; kubectl scale ...` is two commands, not one long read.
    lexer = shlex.shlex(command.replace("\n", " ; "), posix=True, punctuation_chars=True)
    lexer.whitespace_split = True
    try:
        tokens = list(lexer)
    except ValueError:
        return False
    segments: list[list[str]] = []
    current: list[str] | None = None
    for token in tokens:
        if current is None:
            if basename(token) == "kubectl":
                current = [token]
            continue
        if basename(token) == "kubectl":
            segments.append(current)
            current = [token]
            continue
        if token in RELAXED_SHELL_SEPARATORS or set(token) <= set("();<>|&"):
            segments.append(current)
            current = None
            continue
        current.append(token)
    if current is not None:
        segments.append(current)
    if not segments:
        return False
    for segment in segments:
        literal: list[str] = []
        previous = ""
        for token in segment:
            if "$" in token:
                flag, has_inline, _value = token.partition("=")
                if has_inline and flag in RELAXED_KUBECTL_PLACE_FLAGS:
                    literal.append(f"{flag}=pilot-variable-value")
                elif previous in RELAXED_KUBECTL_PLACE_FLAGS:
                    literal.append("pilot-variable-value")
                else:
                    return False
            else:
                literal.append(token)
            previous = token
        if protected_kubectl(literal[1:], [False] * (len(literal) - 1)):
            return False
    return True


def relaxed_disposition(command: str, protected: str) -> str:
    """Return "run", "ask" or "stop" for a recognised command that has no
    reviewed ask form of its own."""
    if protected in RELAXED_KEEP_STOP_LABELS:
        return "stop"
    if protected == "cub space delete" and RELAXED_RECURSIVE_FLAG.search(command):
        return "stop"
    if RELAXED_CONFLICTS_WRITE_FLAG.search(command) and relaxed_cub_words(command)[1] == "conflicts":
        # `cub unit conflicts` and `cub variant conflicts` are reads, but
        # --apply replays the withheld changes and --dismiss drops them. For a
        # variant the name sits where the unit form has its flag, so check the
        # flags themselves.
        return "ask"
    if "<dynamic-" in protected:
        # A plain variable used as a value in a read still reads. A
        # substitution runs something first, a variable in a change can turn
        # it into another change, and a variable inside a flag name can turn a
        # read into one that shows a secret, so those ask. So does any read of
        # a worker, whose JSON carries its secret.
        if "$(" in command or "`" in command or "<(" in command or ">(" in command:
            return "ask"
        if RELAXED_VARIABLE_IN_FLAG_NAME.search(command):
            return "ask"
        if protected.startswith("cub ") and not relaxed_reveals_secret("", command):
            noun, verb, third = relaxed_cub_words(command)
            if noun != "worker" and relaxed_is_read(noun, verb, third):
                return "run"
        if protected == "kubectl <dynamic-argument>" and relaxed_kubectl_variable_read(command):
            return "run"
        return "ask"
    if relaxed_reveals_secret(protected, command):
        return "ask"
    if any(mark in protected for mark in RELAXED_UNBOUNDED_LABEL_MARKS):
        return "ask"
    if protected.endswith(RELAXED_READ_LABEL_SUFFIXES):
        return "run"
    if protected.endswith((" cache-write", " cache-refresh")):
        # These labels mean "this also refreshes cub's local function list".
        # That alone is harmless, but the command underneath may still change
        # a Unit: `cub run --reload set-replicas 2` does. Only a listing, or a
        # get or vet of a function known to be read-only, runs.
        noun, verb, third = relaxed_cub_words(command)
        if noun == "function" and (
            verb == "list" or (verb in {"get", "vet"} and third in READ_ONLY_CUB_RUN_FUNCTIONS)
        ):
            return "run"
        return "ask"
    if protected == "kubectl diff external-executable":
        return "run"
    if protected == "cub variant promote" and relaxed_is_preview(command):
        return "run"
    if relaxed_builtin_group_command(command, protected):
        return "run" if relaxed_is_read(*relaxed_cub_words(command)) else "ask"
    words = protected.split()
    if words and words[0] == "cub":
        noun, verb, third = (words[1:4] + ["", "", ""])[:3]
        if verb == "unreviewed-operation":
            # The label hides the verb; read it from the command.
            _noun, verb, third = relaxed_cub_words(command)
        if relaxed_is_read(noun, verb, third):
            return "run"
    return "ask"


def relaxed_ask_sentence(protected: str, command: str) -> str:
    """One plain sentence on what kind of command the person is being asked about."""
    blame_words = relaxed_cub_words(command)[:2]
    if protected.startswith("cub unit blame") or (
        relaxed_builtin_group_command(command, protected) or protected.endswith(" unreviewed-operation")
    ) and blame_words in RELAXED_BLAME_LIKE_COMMANDS:
        return "It shows other people's changes and values, and follows upstream Units."
    # A built-in group the older noun list does not know is judged by what it
    # is (`cub channel delete`), not by its stand-in plugin label.
    protected = relaxed_display_label(protected, command)
    if protected.startswith(("cub plugin ", "cub upgrade")):
        return "It installs, removes or upgrades a program on this machine."
    if "plugin" in protected or "add-on" in protected or protected.startswith("cub docgen"):
        return "It runs a separate plugin or add-on program, which receives your ConfigHub sign-in."
    if "<dynamic-" in protected:
        return "It contains a variable or a substitution, so Pilot cannot tell from the text exactly what would run."
    if relaxed_reveals_secret(protected, command):
        return "It touches sign-in, tokens, keys or access, or would show a secret."
    if any(mark in protected for mark in RELAXED_UNBOUNDED_LABEL_MARKS):
        return "It names no single Space, so it reads across the organisation."
    if re.search(r"\b(cancel|delete|destroy|dismiss|remove|revoke|unapprove|withdraw)\b", protected):
        return "It deletes or withdraws something."
    if protected.startswith("kubectl "):
        return "It acts on the cluster directly, not through ConfigHub."
    if protected.startswith(("kind ", "pilot local-kind", "local-cluster ")):
        return "It creates or removes a local cluster on this machine."
    if protected.startswith("cub context "):
        return "It changes which ConfigHub context later commands use."
    return "It changes ConfigHub."


def reason_code_tail(code: str, label: str = "") -> str:
    """The machine-readable end of a prompt or stop message.

    A person reads the plain sentences first. Tools that need the code, and
    the hook's own label for the command, read them from here.
    """
    return f"(reason code: {code}; `{label}`)" if label else f"(reason code: {code})"


def kept_stop_reason(protected: str) -> str:
    """Why Pilot stopped a command, in plain words, for the few stops that remain."""
    if protected == INVALID_ADDON_EXECUTABLE_INVENTORY:
        return (
            "Pilot stopped this command, and will stop every command, because one of its own "
            "files is missing or has been changed: the list of add-on programs that ships beside "
            "this check. Nothing was attempted. Reinstall Pilot's Claude adapter, then try again. "
            f"{reason_code_tail('ADDON_EXECUTABLE_POLICY_INVALID', protected)}"
        )
    if protected == "cub cluster detach --delete-config":
        what = (
            "`cub cluster detach --delete-config` disconnects the cluster from ConfigHub and "
            "also deletes its ConfigHub Spaces, and that cannot be undone."
        )
        instead = (
            "Run `cub cluster detach` without `--delete-config` and Pilot will ask first, or run "
            "`pilot teardown-plan` to see every step in order."
        )
    elif protected == "cub cluster down --delete-config":
        what = (
            "`cub cluster down --delete-config` removes the cluster and also deletes its "
            "ConfigHub Spaces, and that cannot be undone."
        )
        instead = (
            "Run `cub cluster down` without `--delete-config` and Pilot will ask first, or run "
            "`pilot teardown-plan` to see every step in order."
        )
    elif protected == "cub organization delete":
        what = "`cub organization delete` deletes a whole organisation, and that cannot be undone."
        instead = "If you mean it, run it yourself in your own terminal."
    else:
        what = (
            "`cub space delete` with `--recursive` deletes a Space and everything in it, and "
            "that cannot be undone."
        )
        instead = (
            "Run `pilot teardown-plan` to see what would be deleted and in what order. If you "
            "still want it, run the delete yourself in your own terminal."
        )
    return (
        f"Pilot stopped this command. {what} A Pilot session does not run it. Nothing was "
        f"attempted. {instead} {reason_code_tail('PILOT_SAFETY_STOP', protected)}"
    )


def interactive_kind_scope(command: str) -> str:
    """Return a human scope summary for one literal `kind` cluster lifecycle call.

    Operator decision 2026-09-23 (#1192): `kind create cluster` and `kind
    delete cluster` touch only this machine's local Docker/Podman containers
    and kubeconfig, never ConfigHub, so any literal single-clause form is
    host-reviewable; there is no narrower reviewed flag grammar to bind since
    kind is not a Pilot/ConfigHub surface.
    """
    tokens = direct_literal_kind_tokens(command)
    if not tokens or is_help(tokens):
        return ""
    verb, verb_index = next_positional(tokens, 1, KIND_GLOBAL_VALUE_FLAGS)
    noun, _ = next_positional(tokens, verb_index + 1, KIND_GLOBAL_VALUE_FLAGS)
    if verb not in {"create", "delete"} or noun != "cluster":
        return ""
    name = single_literal_flag_value(tokens, "--name")
    # kind's own default cluster name, unrelated to any ConfigHub or Pilot
    # naming convention, is literally `kind`.
    cluster_label = f"`{name}`" if name else "the default-named (`kind`)"
    action = "create" if verb == "create" else "delete"
    return f"{action} {cluster_label} local kind cluster on this machine"


try:
    with os.fdopen(3, encoding="utf-8") as event_stream:
        event = json.load(event_stream)
except (OSError, json.JSONDecodeError):
    sys.exit(0)

if event.get("tool_name") != "Bash":
    sys.exit(0)
tool_input = event.get("tool_input") or {}
command = tool_input.get("command", "") if isinstance(tool_input, dict) else ""
if not isinstance(command, str) or not command.strip():
    sys.exit(0)

direct_cub_argv = direct_literal_cub_tokens(command)
direct_cub_clauses = split_shell_clauses(command)
direct_cub_source_is_unmodified = (
    len(direct_cub_clauses) == 1
    and command.strip() == direct_cub_clauses[0]
)
allow_reviewed_unit_projection = bool(
    direct_cub_source_is_unmodified
    and direct_cub_argv
    and direct_cub_argv[0] == "cub"
    and (exact_reviewed_unit_projection(direct_cub_argv[1:])
         or exact_reviewed_dependency_projection(direct_cub_argv[1:]))
)
protected = protected_command(
    command,
    allow_reviewed_unit_projection=allow_reviewed_unit_projection,
)
if not protected:
    sys.exit(0)

# protected_command() reports the first part of a command that it labels. A
# chained command (`;`, `&&`, `||`, `|`, a new line, a loop body) can carry a
# change after a labelled read, so judging the whole command by that first
# label let `cub unit get web -o yaml; cub unit delete web` run without a
# prompt. Judge every part and keep the most serious answer: stop, then ask,
# then run. When a later part decides, the reviewed single-command ask form
# below does not apply.
DISPOSITION_RANK = {"run": 0, "ask": 1, "stop": 2}
decided_disposition = ""
decided_command = command
command_clauses = split_shell_clauses(command)
if len(command_clauses) > 1:
    whole_disposition = relaxed_disposition(command, protected)
    worst_disposition, worst_label = whole_disposition, protected
    worst_command = command
    for command_clause in command_clauses:
        clause_label = protected_command(command_clause)
        if not clause_label:
            continue
        clause_disposition = relaxed_disposition(command_clause, clause_label)
        if DISPOSITION_RANK[clause_disposition] > DISPOSITION_RANK[worst_disposition]:
            worst_disposition, worst_label = clause_disposition, clause_label
            worst_command = command_clause
    if worst_disposition != whole_disposition:
        # A later part decides. Use its answer and its label, and skip the
        # reviewed single-command ask form, which describes one command only.
        decided_disposition = worst_disposition
        protected = worst_label
        decided_command = worst_command

# The shell dispatcher above has already proved exact PILOT_ACTIVE=1. A small
# reviewed ConfigHub subset now uses Claude's native host permission decision.
# It deliberately excludes shell indirection, ambient context, bulk selectors,
# destructive verbs, credentials, direct Kubernetes, and executable lifecycle.
# The decision authorizes only this attempt. Pilot must verify through a later
# read and retain a receipt before describing the requested state as achieved.
interactive_scope = "" if decided_disposition else interactive_cub_scope(command, protected)
# A bare kind cluster call never reaches ConfigHub, so its ask omits the
# ConfigHub-trigger sentence. Wording only: the decision is the same.
trigger_sentence = "ConfigHub triggers may still reject or change it. "
if not interactive_scope and not decided_disposition:
    interactive_scope = interactive_kind_scope(command)
    trigger_sentence = ""
if interactive_scope:
    reason = (
        f"Pilot proposes `{protected}` "
        f"for {interactive_scope}. Approving allows this one exact command and "
        f"nothing else. {trigger_sentence}"
        "Approval is not a check that it worked: afterwards Pilot reads the "
        f"result back. {reason_code_tail('PILOT_INTERACTIVE_PERMISSION_REQUIRED')}"
    )
    json.dump(
        {
            "hookSpecificOutput": {
                "hookEventName": "PreToolUse",
                "permissionDecision": "ask",
                "permissionDecisionReason": reason,
            }
        },
        sys.stdout,
    )
    sys.stdout.write("\n")
    sys.exit(0)

# Operator decision 2026-10-11: reads run, changes ask. Only a bulk delete
# that cannot be undone, and a broken add-on inventory, reach the stop below.
relaxed = decided_disposition or relaxed_disposition(command, protected)
if relaxed == "run":
    sys.exit(0)
if relaxed == "ask":
    reason = (
        "Pilot is asking before this command runs. "
        f"{relaxed_ask_sentence(protected, decided_command)} Review the exact command the host shows, then allow or "
        "decline this one attempt. Approval is not a check that it worked: afterwards Pilot "
        f"reads the result back. {reason_code_tail('PILOT_INTERACTIVE_PERMISSION_REQUIRED', relaxed_display_label(protected, decided_command))}"
    )
    json.dump(
        {
            "hookSpecificOutput": {
                "hookEventName": "PreToolUse",
                "permissionDecision": "ask",
                "permissionDecisionReason": reason,
            }
        },
        sys.stdout,
    )
    sys.stdout.write("\n")
    sys.exit(0)

# What is left is one of the kept stops.
json.dump(
    {
        "hookSpecificOutput": {
            "hookEventName": "PreToolUse",
            "permissionDecision": "deny",
            "permissionDecisionReason": kept_stop_reason(protected),
        }
    },
    sys.stdout,
)
sys.stdout.write("\n")
sys.exit(0)
PY
