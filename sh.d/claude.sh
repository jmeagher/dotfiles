if command -v claude > /dev/null 2>&1 ; then
    _cde() { CLAUDE_CODE_ENABLE_TELEMETRY=1 OTEL_LOG_TOOL_DETAILS=1 \
             claude --permission-mode auto --model "$1" --effort medium "${@:2}"; }
    alias cde='_cde haiku'
    alias cdh='_cde haiku'
    alias cds='_cde sonnet'
    alias cdo='_cde opus'
fi
