package main

import (
	"encoding/json"
	"fmt"
	"net/http"
	"os"
)

const defaultHeaders = "{\"ETag\":\"33a64df551425fcc55e4d42a148795d9f25f89d4\",\"X-Powered-By\":\"Go\",\"X-XSS-Protection\":\"0\",\"X-Content-Type-Options\":\"\",\"Set-Cookie\":\"id=a3fWa; Max-Age=2592000\",\"Set-Cookie\":\"id2=a3fWa2; Max-Age=2593000\"}"

func helloHandler(w http.ResponseWriter, r *http.Request) {
	response := os.Getenv("RESPONSE")
	if len(response) == 0 {
		response = "Hello OpenShift!"
	}

	responseHeaders := os.Getenv("RESPONSE_HEADERS")
	if len(responseHeaders) == 0 {
		responseHeaders = defaultHeaders
	}

	headers := map[string]string{}
	if err := json.Unmarshal([]byte(responseHeaders), &headers); err != nil {
		panic(err)
	}

	for k, v := range headers {
		w.Header().Set(k, v)
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
