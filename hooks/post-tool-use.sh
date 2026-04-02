#!/usr/bin/env bash
# Project Spine: PostToolUse hook
# Reminds to update phase status after Bash operations that change state.

printf '{"systemMessage":"If this Bash command completed a phase, update plan.md status and log.md."}\n'
