package crawler

import (
	"strings"
	"testing"
)

func TestParseRobotsTxt(t *testing.T) {
	tests := []struct {
		name     string
		input    string
		expected []robotsRule
	}{
		{
			name: "basic disallow",
			input: `User-agent: *
Disallow: /private/
Disallow: /tmp/`,
			expected: []robotsRule{
				{path: "/private/", allowed: false},
				{path: "/tmp/", allowed: false},
			},
		},
		{
			name: "allow and disallow",
			input: `User-agent: *
Disallow: /private/
Allow: /private/public/`,
			expected: []robotsRule{
				{path: "/private/", allowed: false},
				{path: "/private/public/", allowed: true},
			},
		},
		{
			name: "ignores non-star user agents",
			input: `User-agent: Googlebot
Disallow: /google-only/

User-agent: *
Disallow: /blocked/`,
			expected: []robotsRule{
				{path: "/blocked/", allowed: false},
			},
		},
		{
			name: "handles comments",
			input: `# This is a robots.txt
User-agent: * # match all
Disallow: /secret/ # secret stuff
Allow: /secret/public/ # but this is fine`,
			expected: []robotsRule{
				{path: "/secret/", allowed: false},
				{path: "/secret/public/", allowed: true},
			},
		},
		{
			name:     "empty input",
			input:    "",
			expected: nil,
		},
		{
			name: "disallow with empty path is ignored",
			input: `User-agent: *
Disallow:`,
			expected: nil,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := parseRobotsTxt(strings.NewReader(tt.input))
			if len(got) != len(tt.expected) {
				t.Fatalf("parseRobotsTxt() returned %d rules, want %d\ngot:  %+v\nwant: %+v", len(got), len(tt.expected), got, tt.expected)
			}
			for i, rule := range got {
				if rule.path != tt.expected[i].path || rule.allowed != tt.expected[i].allowed {
					t.Errorf("rule[%d] = %+v, want %+v", i, rule, tt.expected[i])
				}
			}
		})
	}
}

func TestIsBlocked(t *testing.T) {
	tests := []struct {
		name    string
		rules   []robotsRule
		path    string
		blocked bool
	}{
		{
			name:    "no rules means not blocked",
			rules:   nil,
			path:    "/anything",
			blocked: false,
		},
		{
			name: "simple disallow",
			rules: []robotsRule{
				{path: "/private/", allowed: false},
			},
			path:    "/private/page",
			blocked: true,
		},
		{
			name: "non-matching path is not blocked",
			rules: []robotsRule{
				{path: "/private/", allowed: false},
			},
			path:    "/public/page",
			blocked: false,
		},
		{
			name: "longest prefix match - allow wins",
			rules: []robotsRule{
				{path: "/private/", allowed: false},
				{path: "/private/public/", allowed: true},
			},
			path:    "/private/public/page",
			blocked: false,
		},
		{
			name: "longest prefix match - disallow wins",
			rules: []robotsRule{
				{path: "/a/", allowed: true},
				{path: "/a/b/", allowed: false},
			},
			path:    "/a/b/c",
			blocked: true,
		},
		{
			name: "exact prefix match",
			rules: []robotsRule{
				{path: "/secret", allowed: false},
			},
			path:    "/secret",
			blocked: true,
		},
		{
			name: "prefix must match from start",
			rules: []robotsRule{
				{path: "/secret/", allowed: false},
			},
			path:    "/not-secret/page",
			blocked: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			rc := &RobotsChecker{
				rules:     tt.rules,
				overrides: make(map[string]bool),
			}
			got := rc.isBlocked(tt.path)
			if got != tt.blocked {
				t.Errorf("isBlocked(%q) = %v, want %v", tt.path, got, tt.blocked)
			}
		})
	}
}

func TestIsAllowedPromptYes(t *testing.T) {
	rc := NewRobotsChecker(strings.NewReader("y\n"))
	rc.rules = []robotsRule{
		{path: "/blocked/", allowed: false},
	}
	rc.fetched = true

	allowed := rc.IsAllowed("http://example.com/blocked/page", "/blocked/page")
	if !allowed {
		t.Error("IsAllowed() = false, want true after user answered 'y'")
	}
}

func TestIsAllowedPromptNo(t *testing.T) {
	rc := NewRobotsChecker(strings.NewReader("n\n"))
	rc.rules = []robotsRule{
		{path: "/blocked/", allowed: false},
	}
	rc.fetched = true

	allowed := rc.IsAllowed("http://example.com/blocked/page", "/blocked/page")
	if allowed {
		t.Error("IsAllowed() = true, want false after user answered 'n'")
	}
}

func TestIsAllowedNotBlocked(t *testing.T) {
	rc := NewRobotsChecker(strings.NewReader(""))
	rc.rules = []robotsRule{
		{path: "/blocked/", allowed: false},
	}
	rc.fetched = true

	allowed := rc.IsAllowed("http://example.com/public/page", "/public/page")
	if !allowed {
		t.Error("IsAllowed() = false, want true for non-blocked path")
	}
}

func TestIsAllowedCachesDecision(t *testing.T) {
	// Provide only one "y" answer. The second call for the same URL should
	// use the cached decision without reading from stdin again.
	rc := NewRobotsChecker(strings.NewReader("y\n"))
	rc.rules = []robotsRule{
		{path: "/blocked/", allowed: false},
	}
	rc.fetched = true

	url := "http://example.com/blocked/page"
	path := "/blocked/page"

	first := rc.IsAllowed(url, path)
	if !first {
		t.Fatal("first IsAllowed() = false, want true")
	}

	second := rc.IsAllowed(url, path)
	if !second {
		t.Error("second IsAllowed() = false, want true (should use cached decision)")
	}
}
