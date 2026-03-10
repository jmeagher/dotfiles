package crawler

import (
	"bufio"
	"fmt"
	"io"
	"net/http"
	"os"
	"strings"
	"sync"
)

// RobotsChecker fetches and parses robots.txt, checking whether paths are
// allowed. When a path is disallowed it prompts the user via the provided
// io.Reader for confirmation.
type RobotsChecker struct {
	rules   []robotsRule
	fetched bool
	mu      sync.Mutex

	// stdinReader is used to prompt the user when a URL is blocked.
	// Created once to avoid losing buffered input.
	stdinReader *bufio.Reader
	// overrides remembers per-URL user decisions (true = allow).
	overrides map[string]bool
}

type robotsRule struct {
	path    string
	allowed bool
}

// NewRobotsChecker creates a RobotsChecker that will prompt on the given reader.
func NewRobotsChecker(stdin io.Reader) *RobotsChecker {
	return &RobotsChecker{
		stdinReader: bufio.NewReader(stdin),
		overrides:   make(map[string]bool),
	}
}

// Fetch retrieves and parses robots.txt for the given base URL (scheme + host).
// It only fetches once; subsequent calls are no-ops.
func (rc *RobotsChecker) Fetch(baseURL string) {
	rc.mu.Lock()
	defer rc.mu.Unlock()
	if rc.fetched {
		return
	}
	rc.fetched = true

	robotsURL := strings.TrimRight(baseURL, "/") + "/robots.txt"
	resp, err := http.Get(robotsURL)
	if err != nil {
		// If we cannot fetch robots.txt, allow everything.
		return
	}
	defer resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		return
	}

	rc.rules = parseRobotsTxt(resp.Body)
}

// parseRobotsTxt does a basic parse of robots.txt content. It looks for
// User-agent: * blocks and collects Allow / Disallow rules.
func parseRobotsTxt(r io.Reader) []robotsRule {
	var rules []robotsRule
	scanner := bufio.NewScanner(r)
	inMatchingBlock := false

	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())
		// Strip comments.
		if idx := strings.Index(line, "#"); idx >= 0 {
			line = strings.TrimSpace(line[:idx])
		}
		if line == "" {
			continue
		}

		lower := strings.ToLower(line)
		if strings.HasPrefix(lower, "user-agent:") {
			agent := strings.TrimSpace(line[len("user-agent:"):])
			inMatchingBlock = agent == "*"
			continue
		}

		if !inMatchingBlock {
			continue
		}

		if strings.HasPrefix(lower, "disallow:") {
			path := strings.TrimSpace(line[len("disallow:"):])
			if path != "" {
				rules = append(rules, robotsRule{path: path, allowed: false})
			}
		} else if strings.HasPrefix(lower, "allow:") {
			path := strings.TrimSpace(line[len("allow:"):])
			if path != "" {
				rules = append(rules, robotsRule{path: path, allowed: true})
			}
		}
	}
	return rules
}

// IsAllowed checks whether the given URL path is permitted by robots.txt.
// If the path is disallowed, it prompts the user via stdin. The user's
// decision is cached so the same URL is only asked about once.
func (rc *RobotsChecker) IsAllowed(fullURL, path string) bool {
	rc.mu.Lock()
	defer rc.mu.Unlock()

	if !rc.isBlocked(path) {
		return true
	}

	// Check if we already have a user override for this URL.
	if allowed, ok := rc.overrides[fullURL]; ok {
		return allowed
	}

	// Prompt the user.
	fmt.Fprintf(os.Stderr, "robots.txt blocks crawling of %s. Continue anyway? [y/N]: ", fullURL)

	answer, _ := rc.stdinReader.ReadString('\n')
	answer = strings.TrimSpace(answer)

	allowed := strings.EqualFold(answer, "y")
	rc.overrides[fullURL] = allowed
	return allowed
}

// isBlocked returns true if the path matches a Disallow rule (using longest
// prefix match semantics — the most specific matching rule wins).
func (rc *RobotsChecker) isBlocked(path string) bool {
	bestLen := 0
	blocked := false

	for _, rule := range rc.rules {
		if strings.HasPrefix(path, rule.path) && len(rule.path) > bestLen {
			bestLen = len(rule.path)
			blocked = !rule.allowed
		}
	}
	return blocked
}
