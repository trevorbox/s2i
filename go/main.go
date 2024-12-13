package main

import (
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
)

const defaultHeaders = "{\"headers\":[{\"key\":\"X-Powered-By\",\"value\":\"Go\"},{\"key\":\"X-XSS-Protection\",\"value\":\"0\"},{\"key\":\"X-Content-Type-Options\",\"value\":\"\"},{\"key\":\"Set-Cookie\",\"value\":\"id=a3fWa; Max-Age=2592000\"},{\"key\":\"Set-Cookie\",\"value\":\"id=b3fWa; Max-Age=3592000\"}]}"
const USAGE = "Usage: Set the RESPONSE_HEADERS environment variable to always return custom response headers for a GET request, else static default ones will be returned. Alternatively, send a POST or PUT request with the headers you want returned.\nExample: curl -i -X POST localhost:8080 -d '{\"headers\":[{\"key\":\"k1\",\"value\":\"v2\"}]}'"
const ENV_VAR_RESPONSE_HEADERS = "RESPONSE_HEADERS"

type Headers struct {
	Headers []KV
}

// nested within sbserver response
type KV struct {
	Key   string
	Value string
}

func helloHandler(w http.ResponseWriter, r *http.Request) {

	var response string
	var errorMsg string

	httpResponseCode := http.StatusOK

	headers := &Headers{}
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
					response = "Returned headers from POST or PUT request body."
				}
			}
		}
	}
	if len(headers.Headers) == 0 {
		responseHeaders := os.Getenv(ENV_VAR_RESPONSE_HEADERS)
		if len(responseHeaders) == 0 {
			responseHeaders = defaultHeaders
			response = "Returned hard coded default headers."
		} else {
			response = fmt.Sprintf("Returned headers from the %s environment variable.", ENV_VAR_RESPONSE_HEADERS)
		}
		if err := json.Unmarshal([]byte(responseHeaders), &headers); err != nil {
			httpResponseCode = http.StatusInternalServerError
			errorMsg = err.Error()
		}
	}

	if len(errorMsg) > 0 {
		response = fmt.Sprintf("%s\nError: %s", response, errorMsg)
	}

	response = fmt.Sprintf("%s\n%s", response, USAGE)

	for _, header := range headers.Headers {
		w.Header().Add(header.Key, header.Value)
	}

	w.WriteHeader(httpResponseCode)

	fmt.Fprintln(w, response)
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
	http.HandleFunc("/", helloHandler)
	port := os.Getenv("PORT")
	if len(port) == 0 {
		port = "8080"
	}
	go listenAndServe(port)

	select {}
}
