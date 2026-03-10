package crawler

import (
	"fmt"
	"net/http"
	"net/http/httptest"
	"net/url"
	"sort"
	"strings"
	"testing"
)

func TestNormalizeURL(t *testing.T) {
	tests := []struct {
		name  string
		input string
		want  string
	}{
		{
			name:  "strips fragment",
			input: "http://example.com/page#section",
			want:  "http://example.com/page",
		},
		{
			name:  "no fragment unchanged",
			input: "http://example.com/page",
			want:  "http://example.com/page",
		},
		{
			name:  "empty string",
			input: "",
			want:  "",
		},
		{
			name:  "fragment-only URL",
			input: "#top",
			want:  "",
		},
		{
			name:  "preserves query string but strips fragment",
			input: "http://example.com/page?q=1#frag",
			want:  "http://example.com/page?q=1",
		},
		{
			name:  "invalid URL returns empty",
			input: "://bad",
			want:  "",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := normalizeURL(tt.input)
			if got != tt.want {
				t.Errorf("normalizeURL(%q) = %q, want %q", tt.input, got, tt.want)
			}
		})
	}
}

func TestResolveURL(t *testing.T) {
	base, _ := url.Parse("http://example.com/docs/intro")

	tests := []struct {
		name string
		href string
		want string
	}{
		{
			name: "absolute URL",
			href: "http://other.com/page",
			want: "http://other.com/page",
		},
		{
			name: "relative URL",
			href: "page2",
			want: "http://example.com/docs/page2",
		},
		{
			name: "relative with leading slash",
			href: "/about",
			want: "http://example.com/about",
		},
		{
			name: "strips fragment from resolved",
			href: "page2#section",
			want: "http://example.com/docs/page2",
		},
		{
			name: "parent directory relative",
			href: "../other",
			want: "http://example.com/other",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			got := resolveURL(tt.href, base)
			if got != tt.want {
				t.Errorf("resolveURL(%q, base) = %q, want %q", tt.href, got, tt.want)
			}
		})
	}
}

func TestExtractLinks(t *testing.T) {
	base, _ := url.Parse("http://example.com/docs/")

	tests := []struct {
		name     string
		html     string
		expected []string
	}{
		{
			name:     "extracts href links",
			html:     `<a href="/page1">P1</a><a href="/page2">P2</a>`,
			expected: []string{"http://example.com/page1", "http://example.com/page2"},
		},
		{
			name:     "ignores javascript links",
			html:     `<a href="javascript:void(0)">JS</a><a href="/real">Real</a>`,
			expected: []string{"http://example.com/real"},
		},
		{
			name:     "ignores mailto links",
			html:     `<a href="mailto:test@example.com">Mail</a><a href="/real">Real</a>`,
			expected: []string{"http://example.com/real"},
		},
		{
			name:     "resolves relative URLs",
			html:     `<a href="sub/page">Sub</a>`,
			expected: []string{"http://example.com/docs/sub/page"},
		},
		{
			name:     "ignores form actions",
			html:     `<form action="/submit"><input type="submit"></form><a href="/link">L</a>`,
			expected: []string{"http://example.com/link"},
		},
		{
			name:     "deduplicates links",
			html:     `<a href="/page">A</a><a href="/page">B</a>`,
			expected: []string{"http://example.com/page"},
		},
		{
			name:     "ignores empty href",
			html:     `<a href="">Empty</a><a href="/ok">OK</a>`,
			expected: []string{"http://example.com/ok"},
		},
		{
			name:     "strips fragments from extracted links",
			html:     `<a href="/page#top">Page</a>`,
			expected: []string{"http://example.com/page"},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			r := strings.NewReader(tt.html)
			got := extractLinks(r, base)

			if len(got) != len(tt.expected) {
				t.Fatalf("extractLinks returned %d links, want %d\ngot:  %v\nwant: %v", len(got), len(tt.expected), got, tt.expected)
			}
			for i, link := range got {
				if link != tt.expected[i] {
					t.Errorf("link[%d] = %q, want %q", i, link, tt.expected[i])
				}
			}
		})
	}
}

func TestCrawl(t *testing.T) {
	// Set up a test server with multiple interlinked pages.
	mux := http.NewServeMux()
	mux.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path == "/robots.txt" {
			w.WriteHeader(http.StatusNotFound)
			return
		}
		if r.URL.Path != "/" {
			http.NotFound(w, r)
			return
		}
		fmt.Fprint(w, `<html><body>
			<a href="/page1">Page 1</a>
			<a href="/page2">Page 2</a>
		</body></html>`)
	})
	mux.HandleFunc("/page1", func(w http.ResponseWriter, r *http.Request) {
		fmt.Fprint(w, `<html><body>
			<a href="/page2">Page 2</a>
			<a href="/page1/sub">Sub</a>
		</body></html>`)
	})
	mux.HandleFunc("/page2", func(w http.ResponseWriter, r *http.Request) {
		fmt.Fprint(w, `<html><body>
			<a href="/">Home</a>
		</body></html>`)
	})
	mux.HandleFunc("/page1/sub", func(w http.ResponseWriter, r *http.Request) {
		fmt.Fprint(w, `<html><body><p>Leaf page</p></body></html>`)
	})

	ts := httptest.NewServer(mux)
	defer ts.Close()

	c := New(Config{
		Concurrency: 2,
		MaxDepth:    10,
		Stdin:       strings.NewReader(""),
	})

	urls, err := c.Crawl(ts.URL + "/")
	if err != nil {
		t.Fatalf("Crawl() error: %v", err)
	}

	// Build set of expected URLs.
	expected := map[string]bool{
		ts.URL + "/":         true,
		ts.URL + "/page1":    true,
		ts.URL + "/page2":    true,
		ts.URL + "/page1/sub": true,
	}

	if len(urls) != len(expected) {
		t.Fatalf("Crawl() returned %d URLs, want %d\ngot: %v", len(urls), len(expected), urls)
	}

	for _, u := range urls {
		if !expected[u] {
			t.Errorf("unexpected URL in results: %s", u)
		}
	}
}

func TestCrawlExcludesExternalURLs(t *testing.T) {
	// External server that should not be crawled.
	externalMux := http.NewServeMux()
	externalMux.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		fmt.Fprint(w, `<html><body><p>External</p></body></html>`)
	})
	externalServer := httptest.NewServer(externalMux)
	defer externalServer.Close()

	mux := http.NewServeMux()
	mux.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path == "/robots.txt" {
			w.WriteHeader(http.StatusNotFound)
			return
		}
		if r.URL.Path != "/" {
			http.NotFound(w, r)
			return
		}
		fmt.Fprintf(w, `<html><body>
			<a href="%s">External</a>
			<a href="/internal">Internal</a>
		</body></html>`, externalServer.URL)
	})
	mux.HandleFunc("/internal", func(w http.ResponseWriter, r *http.Request) {
		fmt.Fprint(w, `<html><body><p>Internal page</p></body></html>`)
	})

	ts := httptest.NewServer(mux)
	defer ts.Close()

	c := New(Config{
		Concurrency: 1,
		MaxDepth:    5,
		Stdin:       strings.NewReader(""),
	})

	urls, err := c.Crawl(ts.URL + "/")
	if err != nil {
		t.Fatalf("Crawl() error: %v", err)
	}

	for _, u := range urls {
		if strings.HasPrefix(u, externalServer.URL) {
			t.Errorf("crawled external URL: %s", u)
		}
	}

	// Should contain the internal page.
	found := false
	for _, u := range urls {
		if u == ts.URL+"/internal" {
			found = true
		}
	}
	if !found {
		t.Errorf("did not find internal URL in results: %v", urls)
	}
}

func TestCrawlMaxDepth(t *testing.T) {
	// Create a chain of pages: / -> /d1 -> /d2 -> /d3 -> /d4
	mux := http.NewServeMux()
	mux.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path == "/robots.txt" {
			w.WriteHeader(http.StatusNotFound)
			return
		}
		if r.URL.Path != "/" {
			http.NotFound(w, r)
			return
		}
		fmt.Fprint(w, `<html><body><a href="/d1">D1</a></body></html>`)
	})
	for i := 1; i <= 4; i++ {
		depth := i
		path := fmt.Sprintf("/d%d", depth)
		nextPath := fmt.Sprintf("/d%d", depth+1)
		mux.HandleFunc(path, func(w http.ResponseWriter, r *http.Request) {
			if depth < 4 {
				fmt.Fprintf(w, `<html><body><a href="%s">Next</a></body></html>`, nextPath)
			} else {
				fmt.Fprint(w, `<html><body><p>End</p></body></html>`)
			}
		})
	}

	ts := httptest.NewServer(mux)
	defer ts.Close()

	c := New(Config{
		Concurrency: 1,
		MaxDepth:    2,
		Stdin:       strings.NewReader(""),
	})

	urls, err := c.Crawl(ts.URL + "/")
	if err != nil {
		t.Fatalf("Crawl() error: %v", err)
	}

	// At maxDepth=2:
	// depth 0: / (crawled, fetches links)
	// depth 1: /d1 (crawled, fetches links)
	// depth 2: /d2 (added to results, but depth >= maxDepth so not fetched)
	// /d3 and /d4 should NOT be in results
	sort.Strings(urls)

	allowed := map[string]bool{
		ts.URL + "/":   true,
		ts.URL + "/d1": true,
		ts.URL + "/d2": true,
	}

	for _, u := range urls {
		if !allowed[u] {
			t.Errorf("URL %s should not be present with maxDepth=2", u)
		}
	}

	// /d3 should definitely not be found
	for _, u := range urls {
		if u == ts.URL+"/d3" || u == ts.URL+"/d4" {
			t.Errorf("URL %s found despite maxDepth=2", u)
		}
	}
}

func TestCrawlBaseURLPrefix(t *testing.T) {
	// Start crawl from /docs/ and verify that /other is excluded even on same host.
	mux := http.NewServeMux()
	mux.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		if r.URL.Path == "/robots.txt" {
			w.WriteHeader(http.StatusNotFound)
			return
		}
		http.NotFound(w, r)
	})
	mux.HandleFunc("/docs/", func(w http.ResponseWriter, r *http.Request) {
		fmt.Fprint(w, `<html><body>
			<a href="/docs/page1">P1</a>
			<a href="/other">Other</a>
		</body></html>`)
	})
	mux.HandleFunc("/docs/page1", func(w http.ResponseWriter, r *http.Request) {
		fmt.Fprint(w, `<html><body><p>Doc page</p></body></html>`)
	})
	mux.HandleFunc("/other", func(w http.ResponseWriter, r *http.Request) {
		fmt.Fprint(w, `<html><body><p>Other</p></body></html>`)
	})

	ts := httptest.NewServer(mux)
	defer ts.Close()

	c := New(Config{
		Concurrency: 1,
		MaxDepth:    5,
		Stdin:       strings.NewReader(""),
	})

	urls, err := c.Crawl(ts.URL + "/docs/")
	if err != nil {
		t.Fatalf("Crawl() error: %v", err)
	}

	for _, u := range urls {
		if !strings.HasPrefix(u, ts.URL+"/docs/") {
			t.Errorf("URL %s does not start with base URL prefix %s/docs/", u, ts.URL)
		}
	}
}

func TestCrawlMaxURLs(t *testing.T) {
	// Create a server with 10 interlinked pages.
	ts := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Content-Type", "text/html")
		fmt.Fprint(w, "<html><body>")
		for i := 0; i < 10; i++ {
			fmt.Fprintf(w, `<a href="/page%d">page%d</a>`, i, i)
		}
		fmt.Fprint(w, "</body></html>")
	}))
	defer ts.Close()

	c := New(Config{
		Concurrency: 1,
		MaxDepth:    5,
		MaxURLs:     3,
		Stdin:       strings.NewReader(""),
	})

	urls, err := c.Crawl(ts.URL)
	if err != nil {
		t.Fatalf("Crawl() error: %v", err)
	}

	if len(urls) > 3 {
		t.Errorf("Crawl() returned %d URLs, want at most 3", len(urls))
	}
}
