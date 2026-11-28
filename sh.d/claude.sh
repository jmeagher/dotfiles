if command -v claude > /dev/null 2>&1 ; then
    # Inside a herdr terminal herdr-core sets HC_TERMINAL_ID (the terminal's
    # address); pre-load the herdr-app docs pointer when it is present.
    _cde() {
        _cde_model="$1"; shift
        if [ -n "${HC_TERMINAL_ID:-}" ]; then
            CLAUDE_CODE_ENABLE_TELEMETRY=1 OTEL_LOG_TOOL_DETAILS=1 \
                claude --permission-mode auto --model "$_cde_model" --effort medium \
                --append-system-prompt "Read ~/.config/herdr-app/AGENTS.md for anything related to herdr" "$@"
        else
            CLAUDE_CODE_ENABLE_TELEMETRY=1 OTEL_LOG_TOOL_DETAILS=1 \
                claude --permission-mode auto --model "$_cde_model" --effort medium "$@"
        fi
    }
    alias cde='_cde haiku'
    alias cdh='_cde haiku'
    alias cds='_cde sonnet'
    alias cdo='_cde opus'

    if [ -f "$HOME/.claude/agents/orchestrator.md" ]; then
        alias cor='_cde opus --agent orchestrator'
    fi
fi
