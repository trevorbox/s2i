package main

import (
	"encoding/json"
	"fmt"
	"net/http"
	"os"
)

const defaultHeaders = "{\"headers\":[{\"key\":\"X-Powered-By\",\"value\":\"Go\"},{\"key\":\"X-XSS-Protection\",\"value\":\"0\"},{\"key\":\"X-Content-Type-Options\",\"value\":\"\"},{\"key\":\"Set-Cookie\",\"value\":\"id=a3fWa; Max-Age=2592000\"},{\"key\":\"Set-Cookie\",\"value\":\"id=b3fWa; Max-Age=3592000\"}]}"

type Headers struct {
	Headers []KV
}

// nested within sbserver response
type KV struct {
	Key   string
	Value string
}

func helloHandler(w http.ResponseWriter, r *http.Request) {
	response := os.Getenv("RESPONSE")
	if len(response) == 0 {
		response = "Hello OpenShift!"
	}

	responseHeaders := os.Getenv("RESPONSE_HEADERS")
	if len(responseHeaders) == 0 {
		responseHeaders = defaultHeaders
	}

	headers := &Headers{}
	if err := json.Unmarshal([]byte(responseHeaders), &headers); err != nil {
		panic(err)
	}

	for _, header := range headers.Headers {
		w.Header().Add(header.Key, header.Value)
	}

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
