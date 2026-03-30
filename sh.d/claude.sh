if command -v claude > /dev/null 2>&1 ; then
    alias cde='CLAUDE_CODE_ENABLE_TELEMETRY=1 OTEL_LOG_TOOL_DETAILS=1 claude --enable-auto-mode --model sonnet'
fi
