package main

import (
	"flag"
	"fmt"
	"os"

	"urllist/crawler"
)

func main() {
	concurrency := flag.Int("concurrency", 5, "number of concurrent requests")
	maxDepth := flag.Int("max-depth", 10, "maximum crawl depth")
	flag.Parse()

	args := flag.Args()
	if len(args) < 1 {
		fmt.Fprintln(os.Stderr, "usage: urllist [flags] <url>")
		os.Exit(1)
	}
	startURL := args[0]

	c := crawler.New(crawler.Config{
		Concurrency: *concurrency,
		MaxDepth:    *maxDepth,
		Stdin:       os.Stdin,
	})

	urls, err := c.Crawl(startURL)
	if err != nil {
		fmt.Fprintf(os.Stderr, "error: %v\n", err)
		os.Exit(1)
	}

	for _, u := range urls {
		fmt.Println(u)
	}
}
