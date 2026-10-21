import type { AgentRow, AgentStatus, Doing } from '../types'

export const ENDED = new Set<AgentStatus>(['completed', 'failed', 'killed'])
export const ACTIVE = new Set<AgentStatus>(['running', 'waiting'])

const ENDED_TTL_MS = 10 * 60 * 1000
const MAX_ENDED = 20
const MAX_TEXT = 80

const RANK: Record<AgentStatus, number> = {
  running: 0,
  waiting: 1,
  pending: 2,
  idle: 3,
  failed: 4,
  killed: 5,
  completed: 6,
}

const squash = (s: string) => s.replace(/\s+/g, ' ').trim()

// Mask what looks like a credential: Bearer tokens, key=value pairs, URL userinfo.
export const redact = (s: string): string =>
  s
    .replace(/(bearer\s+)\S+/gi, '$1…')
    .replace(/\b([\w-]*(?:token|secret|key|pass(?:word)?|auth)[\w-]*)=\S+/gi, '$1=…')
    .replace(/(\w+:\/\/)[^@\s/]+@/g, '$1…@')

// Cut by code point so a surrogate pair is never split.
export const clip = (s: string, max = MAX_TEXT): string => {
  const cps = Array.from(squash(s))

  return cps.length > max ? `${cps.slice(0, max - 1).join('')}…` : cps.join('')
}

export const clean = (s: string | undefined, max = MAX_TEXT): string =>
  clip(redact(s ?? ''), max)

const str = (v: unknown): string => (typeof v === 'string' ? v : '')
const base = (p: string) => p.split('/').filter(Boolean).pop() ?? p

// A short, safe line for a tool call: a description the model wrote or a bare
// name, never raw arguments that may hold a secret.
export const summarize = (tool: string, input: Record<string, unknown>): string => {
  const detail = (() => {
    switch (tool) {
      case 'Bash':
      case 'Monitor':
        return str(input.description) || str(input.command).trim().split(/\s+/)[0]
      case 'Read':
      case 'Edit':
      case 'Write':
        return base(str(input.file_path))
      case 'NotebookEdit':
        return base(str(input.notebook_path))
      case 'Grep':
      case 'Glob':
        return str(input.pattern)
      case 'WebFetch':
        return /^\w+:\/\/(?:[^@/]*@)?([^/:?#]+)/.exec(str(input.url))?.[1] ?? ''
      case 'WebSearch':
        return str(input.query)
      case 'Agent':
      case 'Task':
        return str(input.description)
      case 'Skill':
        return str(input.skill)
      case 'SendMessage':
        return str(input.summary)
      case 'TaskCreate':
      case 'TaskUpdate':
        return str(input.activeForm) || str(input.subject)
      case 'TodoWrite': {
        const todos = Array.isArray(input.todos) ? (input.todos as Record<string, unknown>[]) : []

        return str(todos.find(t => t.status === 'in_progress')?.activeForm)
      }
      default:
        return ''
    }
  })()
  const name = tool.startsWith('mcp__') ? (tool.split('__').pop() ?? tool) : tool

  return clean(detail ? `${name}: ${detail}` : name)
}

export const sortRows = (rows: AgentRow[]): AgentRow[] =>
  [...rows].sort(
    (a, b) =>
      (RANK[a.status] ?? 9) - (RANK[b.status] ?? 9) || (b.endedAt ?? 0) - (a.endedAt ?? 0),
  )

// Fold the engine's roster into the rows kept so far: the engine drops an agent
// seconds after it ends, so an agent that left the list is kept, marked done.
export const mergeRoster = (
  prev: AgentRow[],
  listed: Omit<AgentRow, 'startedAt' | 'endedAt'>[],
  now: number,
): AgentRow[] => {
  const before = new Map(prev.map(r => [r.id, r]))
  const seen = new Set(listed.map(r => r.id))
  const current: AgentRow[] = listed.map(r => {
    const old = before.get(r.id)

    return {
      ...r,
      startedAt: old?.startedAt ?? now,
      endedAt: ENDED.has(r.status) ? (old?.endedAt ?? now) : undefined,
    }
  })
  const left: AgentRow[] = prev
    .filter(r => !seen.has(r.id))
    .map(r => (ENDED.has(r.status) ? r : { ...r, status: 'completed', endedAt: now }))
  const ended = [...current.filter(r => ENDED.has(r.status)), ...left]
    .filter(r => now - (r.endedAt ?? now) < ENDED_TTL_MS)
    .sort((a, b) => (b.endedAt ?? 0) - (a.endedAt ?? 0))
    .slice(0, MAX_ENDED)

  return [...current.filter(r => !ENDED.has(r.status)), ...ended]
}

export const elapsed = (r: AgentRow): string => {
  if (r.startedAt === undefined || r.endedAt === undefined) return ''
  const s = Math.max(0, Math.round((r.endedAt - r.startedAt) / 1000))

  return s < 60 ? `${s}s` : `${Math.floor(s / 60)}m${String(s % 60).padStart(2, '0')}s`
}

export type Tone = 'live' | 'dim' | 'error'

// The third line of a row, always present: what the agent is doing now, or how
// it ended. The row renders it indented under the name.
export const statusLine = (r: AgentRow, note?: Doing): { text: string; tone: Tone } => {
  const took = elapsed(r)
  const after = took ? ` after ${took}` : ''

  switch (r.status) {
    case 'running':
    case 'waiting':
      if (note?.isLive) {
        return { text: `↳ ${note.what}${note.more > 0 ? ` (+${note.more})` : ''}`, tone: 'live' }
      }
      if (note) return { text: `last: ${note.what}`, tone: 'dim' }

      return { text: 'waiting for first tool call…', tone: 'dim' }
    case 'pending':
      return { text: 'queued', tone: 'dim' }
    case 'idle':
      return { text: 'idle, waiting for a message', tone: 'dim' }
    case 'completed':
      return { text: `done${took ? ` in ${took}` : ''}`, tone: 'dim' }
    case 'failed':
      return { text: `failed${after}`, tone: 'error' }
    case 'killed':
      return { text: `killed${after}`, tone: 'error' }
    default:
      return { text: String(r.status), tone: 'dim' }
  }
}
