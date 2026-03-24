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

func ParseJSONL(filename string) ([]map[string]any, error) {
	file, err := os.Open(filename)
	if err != nil {
		return nil, fmt.Errorf("failed to open file: %w", err)
	}
	defer file.Close()

	var objects []map[string]any

	scanner := bufio.NewScanner(file)
	buf := make([]byte, 0, 64*1024)
	scanner.Buffer(buf, 1*1024*1024)

	lineNum := 0

	for scanner.Scan() {
		lineNum++

		line := scanner.Bytes()

		var object map[string]any
		if err := json.Unmarshal(line, &object); err != nil {
			return nil, fmt.Errorf("error parsing line %d: %w", lineNum, err)
		}

		objects = append(objects, object)
	}

	return objects, nil
}

func main() {
	events, err := ParseJSONL("trace_TOP.tb.core0.decode_stage_0.decode_monitor_0.jsonl")
	if err != nil {
		log.Fatal(err)
	}

	mux := http.NewServeMux()

	mux.HandleFunc("GET /api/gpr/{cycle}", func(w http.ResponseWriter, r *http.Request) {
		cycle, _ := strconv.Atoi(r.PathValue("cycle"))

		gprs := make(map[int]int)

		for _, event := range events {
			if int(event["cycle"].(float64)) > cycle {
				break
			}

			gprs[int(event["register_index"].(float64))] = int(event["value"].(float64))
		}

		writeJSON(w, http.StatusOK, map[string]any{
			"register_file": gprs,
		})
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
