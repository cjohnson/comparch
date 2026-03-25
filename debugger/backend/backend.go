package main

import (
	"bufio"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"os"
	"strconv"
)

type SignalUpdate struct {
	Cycle  int    `json:"cycle"`
	Signal string `json:"signal"`
	Value  string `json:"value"`
}

func ParseJSONL(filename string) ([]SignalUpdate, error) {
	file, err := os.Open(filename)
	if err != nil {
		return nil, fmt.Errorf("failed to open file: %w", err)
	}
	defer file.Close()

	var updates []SignalUpdate

	scanner := bufio.NewScanner(file)
	buf := make([]byte, 0, 64*1024)
	scanner.Buffer(buf, 1*1024*1024)

	lineNum := 0

	for scanner.Scan() {
		lineNum++

		line := scanner.Bytes()

		var update SignalUpdate
		if err := json.Unmarshal(line, &update); err != nil {
			return nil, fmt.Errorf("error parsing line %d: %w", lineNum, err)
		}

		updates = append(updates, update)
	}

	return updates, nil
}

func main() {
	updates, err := ParseJSONL("trace_TOP.tb.core0.core_monitor_0.jsonl")
	if err != nil {
		log.Fatal(err)
	}

	mux := http.NewServeMux()

	mux.Handle("/", http.FileServer(http.Dir("debugger/frontend/dist")))

	mux.HandleFunc("GET /api/list", func(w http.ResponseWriter, r *http.Request) {
		list_set := make(map[string]any)
		for _, update := range updates {
			list_set[update.Signal] = nil
		}

		list := make([]string, 0)
		for signal := range list_set {
			list = append(list, signal)
		}

		writeJSON(w, http.StatusOK, map[string]any{
			"list": list,
		})
	})

	mux.HandleFunc("GET /api/value/{signal}/{cycle}", func(w http.ResponseWriter, r *http.Request) {
		signal := r.PathValue("signal")
		cycle, _ := strconv.Atoi(r.PathValue("cycle"))

		known := false
		value := ""

		for _, update := range updates {
			if update.Cycle <= cycle && update.Signal == signal {
				known = true
				value = update.Value
			}
		}

		if known {
			writeJSON(w, http.StatusOK, map[string]any{
				"signal": signal,
				"value":  value,
			})
		} else {
			w.WriteHeader(http.StatusNotFound)
		}
	})

	addr := ":8000"
	log.Fatal(http.ListenAndServe(addr, withCORS(mux)))
}

func writeJSON(w http.ResponseWriter, status int, v any) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	if err := json.NewEncoder(w).Encode(v); err != nil {
		log.Printf("write json: %v", err)
	}
}

func withCORS(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Access-Control-Allow-Origin", "*")
		w.Header().Set("Access-Control-Allow-Methods", "GET, OPTIONS")
		w.Header().Set("Access-Control-Allow-Headers", "Content-Type")

		if r.Method == http.MethodOptions {
			w.WriteHeader(http.StatusNoContent)
			return
		}

		next.ServeHTTP(w, r)
	})
}
