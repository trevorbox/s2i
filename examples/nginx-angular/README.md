# Nginx Angular example

Build the angular app using nodejs and serve the built application using nginx.

## build

```sh
podman build -t test .
```

## run

```sh
podman run -it -p 8080:8080 test
```

## run locally

setup...

```sh
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.1/install.sh | bash
nvm install 14
npm install -g @angular/cli
```

build and run...

```sh
cd angular-test
npm install
ng serve
```
