package main

// Ultra-fast network scanner in Go
// Compile: go build -o fast_scanner fast_scanner.go

import (
    "fmt"
    "net"
    "os"
    "strconv"
    "sync"
    "time"
)

func scanPort(host string, port int, wg *sync.WaitGroup, results chan<- int) {
    defer wg.Done()
    
    address := fmt.Sprintf("%s:%d", host, port)
    conn, err := net.DialTimeout("tcp", address, 1*time.Second)
    
    if err == nil {
        conn.Close()
        results <- port
    }
}

func main() {
    if len(os.Args) < 2 {
        fmt.Println("Usage: fast_scanner <host>")
        os.Exit(1)
    }
    
    host := os.Args[1]
    results := make(chan int, 1000)
    var wg sync.WaitGroup
    
    fmt.Printf("Scanning %s...\n", host)
    start := time.Now()
    
    for port := 1; port <= 65535; port++ {
        wg.Add(1)
        go scanPort(host, port, &wg, results)
    }
    
    go func() {
        wg.Wait()
        close(results)
    }()
    
    openPorts := []int{}
    for port := range results {
        fmt.Printf("[+] Port %d is open\n", port)
        openPorts = append(openPorts, port)
    }
    
    elapsed := time.Since(start)
    fmt.Printf("\nFound %d open ports in %s\n", len(openPorts), elapsed)
}
