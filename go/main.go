package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
)

const defaultHeaders = `{"Set-Cookie":["id=a3fWa; Max-Age=2592000","id=b3fWa; Max-Age=3592000"],"X-Content-Type-Options":[""],"X-Powered-By":["Go"],"X-XSS-Protection":["0"]}`
const USAGE = `Usage: Set the RESPONSE_HEADERS environment variable to always return custom response headers for a GET request, else static default headers will be returned. Alternatively, send a POST or PUT request with the headers you want returned as a JSON array of key/value objects. Example: curl -i -X POST localhost:8080 -d '[{"key":"k1","value":"v1"},{"key":"k2","value":"v3"}]'`
const ENV_VAR_RESPONSE_HEADERS = "RESPONSE_HEADERS"

// HeaderKV is one response header to echo back. Repeat the same key for multi-value headers such as Set-Cookie.
type HeaderKV struct {
	Key   string `json:"key"`
	Value string `json:"value"`
}

func parseResponseHeaders(body []byte) (map[string][]string, error) {
	trimmed := bytes.TrimSpace(body)
	if len(trimmed) == 0 {
		return nil, nil
	}

	switch trimmed[0] {
	case '[':
		var kvs []HeaderKV
		if err := json.Unmarshal(trimmed, &kvs); err != nil {
			return nil, err
		}
		headers := make(map[string][]string, len(kvs))
		for _, kv := range kvs {
			if kv.Key == "" {
				continue
			}
			headers[kv.Key] = append(headers[kv.Key], kv.Value)
		}
		return headers, nil
	case '{':
		var headers map[string][]string
		if err := json.Unmarshal(trimmed, &headers); err != nil {
			return nil, err
		}
		return headers, nil
	default:
		return nil, fmt.Errorf("request body must be a JSON array of {key,value} objects or a header map")
	}
}

type ResponseData struct {
	RequestHeaders  map[string][]string `json:"request_headers,omitempty"`
	ResponseHeaders map[string][]string `json:"response_headers,omitempty"`
	Status          string              `json:"status,omitempty"`
	Error           string              `json:"error,omitempty"`
	Usage           string              `json:"usage,omitempty"`
}

func sendResponseHeadersHandler(w http.ResponseWriter, r *http.Request) {

	var response string
	var errorMsg string

	httpResponseCode := http.StatusOK

	var headers map[string][]string
	if r.Method == http.MethodPost || r.Method == http.MethodPut {
		body, err := io.ReadAll(r.Body)
		if err != nil {
			httpResponseCode = http.StatusInternalServerError
			errorMsg = err.Error()
		} else {
			if len(body) > 0 {
				parsed, err := parseResponseHeaders(body)
				if err != nil {
					httpResponseCode = http.StatusBadRequest
					errorMsg = err.Error()
				} else {
					headers = parsed
					response = fmt.Sprintf("Returned headers from %v request body.", r.Method)
				}
			} else {
				response = fmt.Sprintf("Returned no headers from %v request.", r.Method)
			}
		}
	} else {
		responseHeaders := os.Getenv(ENV_VAR_RESPONSE_HEADERS)
		if len(responseHeaders) == 0 {
			responseHeaders = defaultHeaders
			response = fmt.Sprintf("Returned static default headers from %v request.", r.Method)
		} else {
			response = fmt.Sprintf("Returned headers from the %s environment variable for %v request.", ENV_VAR_RESPONSE_HEADERS, r.Method)
		}
		if err := json.Unmarshal([]byte(responseHeaders), &headers); err != nil {
			httpResponseCode = http.StatusInternalServerError
			errorMsg = err.Error()
		}
	}

	for key, values := range headers {
		for _, v := range values {
			w.Header().Add(key, v)
		}
	}

	// TODO these are automatically set. May want to explicitly remove these if not set in request
	// if w.Header().Get("Date") == "" {
	// 	w.Header()["Date"] = nil
	// }
	// if w.Header().Get("Content-Length") == "" {
	// 	w.Header()["Content-Length"] = nil
	// }
	// if w.Header().Get("Content-Type") == "" {
	// 	w.Header()[http.CanonicalHeaderKey("Content-Type")] = nil
	// }
	// if w.Header().Get("Transfer-Encoding") == "" {
	// 	w.Header()["Transfer-Encoding"] = nil
	// }

	w.WriteHeader(httpResponseCode)

	data := ResponseData{r.Header, headers, response, errorMsg, USAGE}

	jsonData, _ := json.MarshalIndent(data, "", " ")

	fmt.Fprintln(w, string(jsonData))
	fmt.Println("Servicing request.")
}

func listenAndServe(port string) {
	fmt.Printf("serving on %s\n", port)
	err := http.ListenAndServe(":"+port, nil)
	if err != nil {
		panic("ListenAndServe: " + err.Error())
	}
}

func main() {
	http.HandleFunc("/", sendResponseHeadersHandler)
	port := os.Getenv("PORT")
	if len(port) == 0 {
		port = "8080"
	}
	go listenAndServe(port)

	select {}
}
