package crawler

import (
	"fmt"
	"io"
	"math"
	"net/http"
	"net/url"
	"os"
	"strings"
	"sync"
	"time"

	"golang.org/x/net/html"
)

// httpClient is the HTTP client used for all requests, with a reasonable timeout.
var httpClient = &http.Client{Timeout: 30 * time.Second}

// Config holds the crawler configuration.
type Config struct {
	Concurrency int
	MaxDepth    int
	MaxURLs     int
	Stdin       io.Reader
}

// Crawler holds the state and configuration for a crawl session.
type Crawler struct {
	config    Config
	baseURL   string
	visited   map[string]bool
	mu        sync.Mutex
	semaphore chan struct{}
	robots    *RobotsChecker
	results   []string
}

// New creates a new Crawler with the given configuration.
func New(cfg Config) *Crawler {
	if cfg.Concurrency < 1 {
		cfg.Concurrency = 5
	}
	if cfg.MaxDepth < 1 {
		cfg.MaxDepth = 10
	}
	if cfg.MaxURLs < 1 {
		cfg.MaxURLs = 10000
	}
	stdin := cfg.Stdin
	if stdin == nil {
		stdin = strings.NewReader("")
	}
	return &Crawler{
		config:    cfg,
		visited:   make(map[string]bool),
		semaphore: make(chan struct{}, cfg.Concurrency),
		robots:    NewRobotsChecker(stdin),
	}
}

// Crawl starts crawling from startURL and returns all discovered URLs that
// share the same base prefix.
func (c *Crawler) Crawl(startURL string) ([]string, error) {
	parsed, err := url.Parse(startURL)
	if err != nil {
		return nil, fmt.Errorf("invalid start URL: %w", err)
	}

	if parsed.Scheme != "http" && parsed.Scheme != "https" {
		return nil, fmt.Errorf("unsupported scheme %q: only http and https are supported", parsed.Scheme)
	}

	// Normalize the start URL.
	parsed.Fragment = ""
	startURL = parsed.String()

	// Base URL is the normalized start URL. We match any URL that starts
	// with this prefix.
	c.baseURL = startURL

	// Fetch robots.txt for the site root.
	robotsBase := parsed.Scheme + "://" + parsed.Host
	c.robots.Fetch(robotsBase)

	var wg sync.WaitGroup
	c.crawlURL(startURL, 0, &wg)
	wg.Wait()

	return c.results, nil
}

// crawlURL processes a single URL at the given depth.
func (c *Crawler) crawlURL(rawURL string, depth int, wg *sync.WaitGroup) {
	normalized := normalizeURL(rawURL)
	if normalized == "" {
		return
	}

	c.mu.Lock()
	if c.visited[normalized] || len(c.results) >= c.config.MaxURLs {
		c.mu.Unlock()
		return
	}
	c.visited[normalized] = true
	c.results = append(c.results, normalized)
	c.mu.Unlock()

	if depth >= c.config.MaxDepth {
		return
	}

	// Check robots.txt.
	parsed, err := url.Parse(normalized)
	if err != nil {
		return
	}
	if !c.robots.IsAllowed(normalized, parsed.Path) {
		return
	}

	wg.Add(1)
	go func() {
		defer wg.Done()

		// Acquire semaphore.
		c.semaphore <- struct{}{}
		defer func() { <-c.semaphore }()

		body, err := fetchWithRetry(normalized, 3, time.Second)
		if err != nil {
			fmt.Fprintf(os.Stderr, "failed to fetch %s: %v\n", normalized, err)
			return
		}
		defer body.Close()

		links := extractLinks(body, parsed)

		for _, link := range links {
			if strings.HasPrefix(link, c.baseURL) {
				c.crawlURL(link, depth+1, wg)
			}
		}
	}()
}

// normalizeURL strips fragments and cleans up the URL.
func normalizeURL(rawURL string) string {
	parsed, err := url.Parse(rawURL)
	if err != nil {
		return ""
	}
	parsed.Fragment = ""
	return parsed.String()
}

// fetchWithRetry performs an HTTP GET with exponential backoff.
// It retries on network errors, 5xx responses, and 429 Too Many Requests.
func fetchWithRetry(targetURL string, maxRetries int, baseDelay time.Duration) (io.ReadCloser, error) {
	var lastErr error
	for attempt := 0; attempt < maxRetries; attempt++ {
		if attempt > 0 {
			delay := baseDelay * time.Duration(math.Pow(2, float64(attempt-1)))
			time.Sleep(delay)
		}

		resp, err := httpClient.Get(targetURL)
		if err != nil {
			lastErr = err
			fmt.Fprintf(os.Stderr, "attempt %d for %s failed: %v\n", attempt+1, targetURL, err)
			continue
		}
		if resp.StatusCode == http.StatusTooManyRequests || resp.StatusCode >= 500 {
			resp.Body.Close()
			lastErr = fmt.Errorf("HTTP %d", resp.StatusCode)
			fmt.Fprintf(os.Stderr, "attempt %d for %s: HTTP %d\n", attempt+1, targetURL, resp.StatusCode)
			continue
		}
		if resp.StatusCode != http.StatusOK {
			resp.Body.Close()
			return nil, fmt.Errorf("HTTP %d for %s", resp.StatusCode, targetURL)
		}
		return resp.Body, nil
	}
	return nil, fmt.Errorf("all %d attempts failed for %s: %w", maxRetries, targetURL, lastErr)
}

// extractLinks parses HTML from r and returns all href attribute values from
// <a> tags, resolved against the base URL.
func extractLinks(r io.Reader, base *url.URL) []string {
	tokenizer := html.NewTokenizer(r)
	var links []string
	seen := make(map[string]bool)

	for {
		tt := tokenizer.Next()
		switch tt {
		case html.ErrorToken:
			return links
		case html.StartTagToken, html.SelfClosingTagToken:
			t := tokenizer.Token()
			// Only extract href from <a> tags.
			if t.Data != "a" {
				continue
			}
			for _, attr := range t.Attr {
				if attr.Key != "href" {
					continue
				}
				href := strings.TrimSpace(attr.Val)
				if href == "" || strings.HasPrefix(href, "javascript:") || strings.HasPrefix(href, "mailto:") {
					continue
				}

				resolved := resolveURL(href, base)
				if resolved == "" {
					continue
				}
				if !seen[resolved] {
					seen[resolved] = true
					links = append(links, resolved)
				}
			}
		}
	}
}

// resolveURL resolves a potentially relative href against the base URL
// and normalizes it (strips fragment).
func resolveURL(href string, base *url.URL) string {
	parsed, err := url.Parse(href)
	if err != nil {
		return ""
	}
	resolved := base.ResolveReference(parsed)
	resolved.Fragment = ""
	return resolved.String()
}
