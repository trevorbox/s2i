fmt: ## Run go fmt against code.
	go fmt ./...

vet: ## Run go vet against code.
	go vet ./...

build: fmt vet
	go build -o bin/

run: fmt vet ## Run locally
	go run ./main.go

test: fmt vet
	go test ./... -coverprofile cover.out
    