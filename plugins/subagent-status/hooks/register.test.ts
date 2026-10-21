import { test, expect, mock } from 'claude-code/testing'
import type { Engine } from 'claude-code/testing'

import { mergeRoster, redact, statusLine, summarize } from './logic'

const row = (id: string, status: 'running' | 'completed' | 'idle' | 'failed') => ({
  id, name: id, type: 'Explore', description: 'task', status,
})

const mount = ($: Engine) =>
  $.ui.mount({
    plugin: 'subagent-status',
    surface: 'terminal',
    component: 'Pane',
    requestId: 'subagent-status',
    props: {} as never,
  })

test('the pane says so when no subagent has run', async $ => {
  for (const surface of ['terminal', 'desktop'] as const) {
    const ui = await $.ui.mount({
      plugin: 'subagent-status',
      surface,
      component: 'Pane',
      requestId: 'subagent-status',
      props: {} as never,
    })
    expect(await ui.find({ type: 'Text', text: /No subagents yet/ })).toBeDefined()
    await ui.unmount()
  }
})

test('the pane lists a polled subagent, then keeps it as done when it leaves the roster', async ($, on) => {
  const clock = mock.clock(on)
  let roster: unknown[] = [row('a1', 'running')]
  on('session.start', () => ({ cwd: '/tmp' }))
  on('command.register', () => ({ value: undefined } as never))
  on('ui.open', () => ({ value: { isPlaced: true } }))
  on('agent.list', () => ({ value: roster as never }))
  await $.session.start({ cwd: '/tmp', surface: 'terminal', isInteractive: true })
  await clock.advance(1000)
  let ui = await mount($)
  expect(await ui.find({ type: 'Text', text: /running/ })).toBeDefined()
  expect(await ui.find({ type: 'Text', text: /task: task/ })).toBeDefined()
  await ui.unmount()

  roster = []
  await clock.advance(1000)
  ui = await mount($)
  expect(await ui.find({ type: 'Text', text: /done/ })).toBeDefined()
  expect(await ui.find({ type: 'Text', text: /a1/ })).toBeDefined()
  await ui.unmount()
})

test('a poll that fails once recovers on the next tick', async ($, on) => {
  const clock = mock.clock(on)
  let calls = 0
  on('session.start', () => ({ cwd: '/tmp' }))
  on('command.register', () => ({ value: undefined } as never))
  on('ui.open', () => ({ value: { isPlaced: true } }))
  on('agent.list', () => {
    if (++calls === 1) throw new Error('boom')

    return { value: [row('b1', 'running')] as never }
  })
  await $.session.start({ cwd: '/tmp', surface: 'terminal', isInteractive: true })
  await clock.advance(1000)
  await clock.advance(1000)
  const ui = await mount($)
  expect(await ui.find({ type: 'Text', text: /b1/ })).toBeDefined()
  await ui.unmount()
})

test('/subagents says when the pane could not be placed', async ($, on) => {
  on('ui.open', () => ({ value: { isPlaced: false, reason: 'too narrow' } }))
  const out = await $.command.run({ command: 'subagents' } as never)
  expect(JSON.stringify(out)).toContain('too narrow')
})

test('mergeRoster keeps a vanished agent as done, then drops it after the TTL', () => {
  const kept = mergeRoster([], [row('x', 'running')], 1000)
  const gone = mergeRoster(kept, [], 5000)
  expect(gone[0]).toMatchObject({ id: 'x', status: 'completed', endedAt: 5000 })
  expect(mergeRoster(gone, [], 5000 + 11 * 60 * 1000)).toEqual([])
})

test('mergeRoster revives an agent that resumes', () => {
  const ended = mergeRoster([], [row('x', 'completed')], 1000)
  const back = mergeRoster(ended, [row('x', 'running')], 2000)
  expect(back[0]).toMatchObject({ status: 'running', endedAt: undefined })
})

test('summarize shows a description or bare name, not raw arguments', () => {
  expect(summarize('Bash', { command: 'FOO_TOKEN=abc curl x', description: 'Fetch page' })).toBe(
    'Bash: Fetch page',
  )
  expect(summarize('Bash', { command: 'curl -H secret' })).toBe('Bash: curl')
  expect(summarize('Read', { file_path: '/Users/me/.ssh/config' })).toBe('Read: config')
  expect(summarize('WebFetch', { url: 'https://u:p@example.com/a?token=1' })).toBe(
    'WebFetch: example.com',
  )
  expect(summarize('mcp__drive__search_files', { query: 'private' })).toBe('search_files')
})

test('redact masks credentials that slip through', () => {
  expect(redact('Authorization: Bearer abc123')).toBe('Authorization: Bearer …')
  expect(redact('API_KEY=sk-123 run')).toBe('API_KEY=… run')
})

test('statusLine gives every status a third line', () => {
  const r = (status: string, startedAt?: number, endedAt?: number) =>
    ({ ...row('x', 'running'), status, startedAt, endedAt }) as never
  const live = { what: 'Read: a.ts', isLive: true, more: 0 }
  const busy = { what: 'Read: a.ts', isLive: true, more: 2 }
  const past = { what: 'Grep: foo', isLive: false, more: 0 }

  expect(statusLine(r('running'), live)).toEqual({ text: '↳ Read: a.ts', tone: 'live' })
  expect(statusLine(r('waiting'), busy)).toEqual({ text: '↳ Read: a.ts (+2)', tone: 'live' })
  expect(statusLine(r('running'), past)).toEqual({ text: 'last: Grep: foo', tone: 'dim' })
  expect(statusLine(r('running'))).toEqual({ text: 'waiting for first tool call…', tone: 'dim' })
  expect(statusLine(r('pending'))).toEqual({ text: 'queued', tone: 'dim' })
  expect(statusLine(r('idle'))).toEqual({ text: 'idle, waiting for a message', tone: 'dim' })
  expect(statusLine(r('completed', 0, 75000))).toEqual({ text: 'done in 1m15s', tone: 'dim' })
  expect(statusLine(r('failed', 0, 4000))).toEqual({ text: 'failed after 4s', tone: 'error' })
  expect(statusLine(r('killed', 0, 4000))).toEqual({ text: 'killed after 4s', tone: 'error' })
  expect(statusLine(r('failed'))).toEqual({ text: 'failed', tone: 'error' })
  expect(statusLine(r('completed'))).toEqual({ text: 'done', tone: 'dim' })
})
