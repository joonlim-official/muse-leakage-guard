#!/usr/bin/env bash
# patterns.sh — candidate-extraction patterns for the synthetic stub's
# test-double detector (test/stub-memory-skill).
#
# These are PUBLIC SHAPES, not secrets: they describe what a token looks
# like so the stub can find candidates in its input. The VERDICT for a
# candidate comes from bin/blockset.txt (sha256 hashes of the declared
# synthetic block-tier tokens), never from these patterns. Anything
# secret-shaped that is NOT in the block set is treated as review-tier
# (rc=2, fail closed). This stub is a test double for harness
# self-consistency checks — it is not a detector and must never be
# deployed as a protection layer. See ../README.md and
# ../../../references/gate-interface.md (interface version 1).
#
# Sourced by bin/memory-egress-check and by build/build-blockset.sh so the
# build-time hash set and the runtime extractor can never disagree.

# Secret-shaped candidates (superset of the shapes the audit's fixture-purity
# check looks for, plus the api_key=/password= and bare-digit shapes the
# adversarial corpus exercises). ERE for grep -E.
STUB_SECRET_CAND='[0-9]{3}-[0-9]{2}-[0-9]{4}|\b[0-9]{9}\b|\b[0-9]{4}([- ]?[0-9]{4}){3}\b|\b3[47][0-9]{2}([- ]?[0-9]{6})([- ]?[0-9]{5})\b|sk_(live|test)_[A-Za-z0-9]+|sk-[A-Za-z0-9_-]{20,}|gsk_[A-Za-z0-9]+|AKIA[0-9A-Z]{16}|xox[bpas]-[A-Za-z0-9-]+|AIza[A-Za-z0-9_-]+|ghp_[A-Za-z0-9]+|BEGIN [A-Z ]*PRIVATE KEY|api[ _-]?key["'"'"' ]*[:=]["'"'"' ]*[A-Za-z0-9_.-]{16,}|password["'"'"' ]*[:=]["'"'"' ]*[^ ]+|passwd["'"'"' ]*[:=]["'"'"' ]*[^ ]+'

# Figure-shaped candidates: dollar figures the corpus marks review-tier.
# Bare single-dollar amounts ($1, $5) are deliberately NOT candidates —
# they are shell positional parameters / trivial sums (documented residual).
STUB_FIGURE_CAND='\$([0-9]{1,3}(,[0-9]{3})+|[0-9]{2,}|[0-9]*\.[0-9]+|[0-9]+[kKmM])'

# Phone-shaped candidates: separator-required, like the real gate. Bare
# 10-digit numbers are deliberately NOT candidates — they collide with
# order/confirmation numbers (documented residual, corpus phone_bare10).
STUB_PHONE_CAND='(\+?1[-. ]?)?\(?[0-9]{3}\)?[-. ][0-9]{3}[-. ][0-9]{4}'
