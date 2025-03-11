package main

import (
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
)

const defaultHeaders = `{"Set-Cookie":["id=a3fWa; Max-Age=2592000","id=b3fWa; Max-Age=3592000"],"X-Content-Type-Options":[""],"X-Powered-By":["Go"],"X-XSS-Protection":["0"]}`
const USAGE = `Usage: Set the RESPONSE_HEADERS environment variable to always return custom response headers for a GET request, else static default headers will be returned. Alternatively, send a POST or PUT request with the headers you want returned. Example: curl -i -X POST localhost:8080 -d '{"k1":["v1"],"k2":["v3","v4"]}'`
const ENV_VAR_RESPONSE_HEADERS = "RESPONSE_HEADERS"

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
				if err := json.Unmarshal(body, &headers); err != nil {
					httpResponseCode = http.StatusBadRequest
					errorMsg = err.Error()
				} else {
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
