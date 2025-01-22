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
	RequestHeaders  map[string][]string
	ResponseHeaders map[string][]string
	Status          string
	Error           string
	Usage           string
}

func helloHandler(w http.ResponseWriter, r *http.Request) {

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
					response = "Returned headers from POST or PUT request body."
				}
			}
		}
	}
	if len(headers) == 0 {
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

	for key, values := range headers {
		for _, v := range values {
			w.Header().Add(key, v)
		}
	}

	w.WriteHeader(httpResponseCode)

	data := ResponseData{r.Header, headers, response, errorMsg, USAGE}

	jsonData, _ := json.MarshalIndent(data, "", " ")
	//TODO pretty print json
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
	http.HandleFunc("/", helloHandler)
	port := os.Getenv("PORT")
	if len(port) == 0 {
		port = "8080"
	}
	go listenAndServe(port)

	select {}
}
