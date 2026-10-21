import { atom, read, update } from 'claude-code'
import type { Color, Register } from 'claude-code'

import type { AgentRow, AgentStatus, Doing } from '../types'
import { ACTIVE, ENDED, clean, mergeRoster, sortRows, statusLine, summarize } from './logic'

const PANE = 'subagent-status'
const TITLE = 'Subagents'
const DOCK_COLUMNS = 38
const POLL_MS = 1000
const REOPEN_EVERY_TICKS = 5
const agents = atom({ plugin: 'subagent-status', key: 'agents' } as const, [])
const doingAtom = atom({ plugin: 'subagent-status', key: 'doing' } as const, {})

type Look = { mark: string; color: Color; word: string }
const LOOK: Record<AgentStatus, Look> = {
  running: { mark: '●', color: 'success', word: 'running' },
  waiting: { mark: '◐', color: 'warning', word: 'waiting' },
  pending: { mark: '○', color: 'warning', word: 'pending' },
  idle: { mark: '◌', color: 'inactive', word: 'idle' },
  completed: { mark: '✓', color: 'subtle', word: 'done' },
  failed: { mark: '✗', color: 'error', word: 'failed' },
  killed: { mark: '■', color: 'error', word: 'killed' },
}
const UNKNOWN: Look = { mark: '?', color: 'inactive', word: 'unknown' }
const ORDER: AgentStatus[] = [
  'running', 'waiting', 'pending', 'idle', 'failed', 'killed', 'completed',
]

export const register: Register = on => {
  // Scratch that is safe to lose on a reload; the host keeps the atoms.
  let generation = 0
  let rows: AgentRow[] = []
  let isPlaced = false
  let isDismissed = false
  const inFlight = new Map<string, { agentId: string; what: string }>()
  const lastDone = new Map<string, string>()
  let timer: { cancel: () => void } | undefined

  on('session.start', async ($, e, next) => {
    await $.command.register({
      name: 'subagents',
      description: 'Open the subagent status side panel',
    })

    const open = async () => {
      try {
        const r = await $.ui.open({ id: PANE, title: TITLE, columns: DOCK_COLUMNS })
        isPlaced = r.isPlaced
      } catch {
        isPlaced = false
      }
    }
    // Opened unasked, the pane waits undrawn on a terminal under 144 columns;
    // the poll below retries so it docks once the terminal is wide enough.
    await open()

    // Carry the kept rows across a reload.
    await update($, agents, prev => {
      if (rows.length === 0) rows = prev

      return prev
    })

    const gen = ++generation
    let ticks = 0
    let isBusy = false
    let lastRows = ''
    let lastDoing = ''
    timer?.cancel()
    timer = $.clock.every(POLL_MS, async () => {
      if (isBusy) return
      isBusy = true
      try {
        const listed = (await $.agent.list()).map(a => ({
          id: a.id,
          name: a.name ?? a.teammateId ?? a.id.slice(0, 8),
          type: a.type,
          description: a.description,
          status: a.status,
          parentId: a.parentId,
        }))
        const now = await $.clock.now()
        if (gen !== generation) return

        const merged = mergeRoster(rows, listed, now)
        const rowsKey = JSON.stringify(merged)
        if (rowsKey !== lastRows) {
          await update($, agents, () => merged)
          if (gen !== generation) return
          rows = merged
          lastRows = rowsKey
        }

        const doing: Record<string, Doing> = {}
        for (const r of merged) {
          if (!ACTIVE.has(r.status)) continue
          const live = [...inFlight.values()].filter(c => c.agentId === r.id)
          const newest = live[live.length - 1]
          const last = lastDone.get(r.id)
          if (newest) doing[r.id] = { what: newest.what, isLive: true, more: live.length - 1 }
          else if (last) doing[r.id] = { what: last, isLive: false, more: 0 }
        }
        for (const id of lastDone.keys()) {
          if (!merged.some(r => r.id === id && ACTIVE.has(r.status))) lastDone.delete(id)
        }
        const doingKey = JSON.stringify(doing)
        if (doingKey !== lastDoing) {
          await update($, doingAtom, () => doing)
          if (gen !== generation) return
          lastDoing = doingKey
        }

        if (!isPlaced && !isDismissed && ++ticks % REOPEN_EVERY_TICKS === 0) await open()
      } catch {
        // `last*` only advance after a successful write, so the next tick retries.
      } finally {
        isBusy = false
      }
    })

    return next(e)
  })

  // /clear starts a new conversation without a session.start: drop what we kept.
  on('session.end', async ($, e, next) => {
    if (e.reason === 'clear') {
      rows = []
      inFlight.clear()
      lastDone.clear()
      await update($, agents, () => [])
      await update($, doingAtom, () => ({}))
    }

    return next(e)
  })

  on('ui.close', { id: PANE }, ($, e, next) => {
    if (e.origin.kind === 'person') {
      isDismissed = true
      isPlaced = false
    }

    return next(e)
  }).catch(($, e, next) => next(e)) // an observer: never keep the person's close from landing

  on('command.run', { command: 'subagents' }, async ($, e) => {
    isDismissed = false
    const r = await $.ui.open({ id: PANE, title: TITLE, columns: DOCK_COLUMNS })
    isPlaced = r.isPlaced
    if (!r.isPlaced) return { text: `Subagents panel is waiting: ${r.reason}.` }
    if (!e.presentation.isFullscreen) {
      return {
        text: 'Subagents panel opened above the prompt: the side dock needs the fullscreen layout (CLAUDE_CODE_NO_FLICKER=1).',
      }
    }
    if (e.presentation.columns < 110) {
      return { text: 'Subagents panel opened, but the terminal is under 110 columns, too narrow to dock.' }
    }

    return { text: 'Subagents panel opened beside the transcript.' }
  })

  // Synchronous bookkeeping on the call's critical path; the poll flushes it.
  on('tool.call', async (_, e, next) => {
    const agentId = e.agentId
    if (!agentId) return next(e)

    const what = summarize(e.tool, e as unknown as Record<string, unknown>)
    inFlight.set(e.tool_use_id, { agentId, what })
    try {
      return await next(e)
    } finally {
      inFlight.delete(e.tool_use_id)
      lastDone.set(agentId, what)
    }
  }).catch((_, e, next) => next(e)) // an observer: fail open, never block the call

  on('ui.render', { component: 'Pane', requestId: PANE }, async ($, e) => {
    const { Box, Text } = $.ui.resolve(e)
    const list = sortRows(await read($, agents))
    const doing = await read($, doingAtom)
    const looks = (s: AgentStatus) => LOOK[s] ?? UNKNOWN

    return (
      <Box flexDirection="column">
        {list.length === 0 && <Text dimColor>No subagents yet.</Text>}
        {list.length > 0 && (
          <Text>
            {ORDER.filter(s => list.some(r => r.status === s)).map((s, i) => (
              <Text key={s} color={looks(s).color}>
                {i > 0 ? ' · ' : ''}
                {looks(s).mark} {list.filter(r => r.status === s).length} {looks(s).word}
              </Text>
            ))}
          </Text>
        )}
        {list.map(r => {
          const look = looks(r.status)
          const note = doing[r.id]
          const line = statusLine(r, note)

          return (
            <Box key={r.id} flexDirection="column" marginTop={1}>
              <Text wrap="truncate-end">
                <Text color={look.color}>
                  {look.mark} {look.word}
                </Text>{' '}
                <Text bold dimColor={r.status === 'completed'}>
                  {clean(r.name, 40)}
                </Text>
                <Text dimColor> · {clean(r.type, 24)}</Text>
              </Text>
              <Text wrap="truncate-end" dimColor>
                {'  task: '}
                {clean(r.description) || '(no description)'}
              </Text>
              <Text
                wrap="truncate-end"
                color={line.tone === 'live' ? 'suggestion' : line.tone === 'error' ? 'error' : undefined}
                dimColor={line.tone === 'dim'}
              >
                {'  '}
                {line.text}
              </Text>
            </Box>
          )
        })}
      </Box>
    )
  })
}
