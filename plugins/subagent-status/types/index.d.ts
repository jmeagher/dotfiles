export type AgentStatus =
  | 'pending'
  | 'running'
  | 'waiting'
  | 'idle'
  | 'completed'
  | 'failed'
  | 'killed'

export type AgentRow = {
  id: string
  name: string
  type: string
  description: string
  status: AgentStatus
  parentId?: string
  startedAt?: number
  endedAt?: number
}

/** What one live agent is doing: its newest tool call in flight, else its last. */
export type Doing = { what: string; isLive: boolean; more: number }

declare module 'claude-code' {
  interface PluginState {
    'subagent-status': { agents: AgentRow[]; doing: Record<string, Doing> }
  }
}
