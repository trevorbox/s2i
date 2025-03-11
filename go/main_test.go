package main

import (
	"encoding/json"
	"io"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"

	"github.com/stretchr/testify/assert"
)

func TestGet(t *testing.T) {
	req := httptest.NewRequest(http.MethodGet, "/", nil)
	w := httptest.NewRecorder()
	sendResponseHeadersHandler(w, req)

	res := w.Result()
	h := res.Header
	assert.NotNil(t, h)

	var defaultHeadersMap map[string][]string
	responseHeaders := defaultHeaders
	err := json.Unmarshal([]byte(responseHeaders), &defaultHeadersMap)
	assert.Nil(t, err)

	for key, values := range defaultHeadersMap {
		v := h.Values(key)
		assert.Equal(t, values, v, key)
	}
}

func TestPost(t *testing.T) {

	postData := "{\"k1\":[\"v1\"],\"k2\":[\"v3\",\"v4\"]}"

	req := httptest.NewRequest(http.MethodPost, "/", strings.NewReader(postData))
	w := httptest.NewRecorder()
	sendResponseHeadersHandler(w, req)

	res := w.Result()
	h := res.Header
	assert.NotNil(t, h)

	var expected map[string][]string
	err := json.Unmarshal([]byte(postData), &expected)
	assert.Nil(t, err)

	assert.Equal(t, 2, len(h), h)

	for key, values := range expected {
		v := h.Values(key)
		assert.Equal(t, values, v, key)
	}
}

func TestBadPost(t *testing.T) {

	postData := "{\"k1\":[\"v1\"],\"k2\":[\"v3\",\"v4\"]"

	req := httptest.NewRequest(http.MethodPost, "/", strings.NewReader(postData))
	w := httptest.NewRecorder()
	sendResponseHeadersHandler(w, req)

	res := w.Result()
	h := res.Header
	assert.NotNil(t, h)
	assert.Equal(t, 0, len(h), h)

	var responseData ResponseData
	body, _ := io.ReadAll(res.Body)
	err := json.Unmarshal([]byte(body), &responseData)
	assert.Nil(t, err)
	assert.NotNil(t, responseData)

	assert.Equal(t, "unexpected end of JSON input", responseData.Error)

}

func TestPut(t *testing.T) {

	postData := "{\"k1\":[\"v1\"],\"k2\":[\"v3\",\"v4\"]}"

	req := httptest.NewRequest(http.MethodPut, "/", strings.NewReader(postData))
	w := httptest.NewRecorder()
	sendResponseHeadersHandler(w, req)

	res := w.Result()
	h := res.Header
	assert.NotNil(t, h)

	var expected map[string][]string
	err := json.Unmarshal([]byte(postData), &expected)
	assert.Nil(t, err)

	assert.Equal(t, 2, len(h), h)

	for key, values := range expected {
		v := h.Values(key)
		assert.Equal(t, values, v, key)
	}
}

func TestPostNoData(t *testing.T) {

	req := httptest.NewRequest(http.MethodPost, "/", nil)
	w := httptest.NewRecorder()
	sendResponseHeadersHandler(w, req)

	res := w.Result()
	h := res.Header
	assert.NotNil(t, h)

	assert.Equal(t, 0, len(h), h)

}

func TestPostNoPut(t *testing.T) {

	req := httptest.NewRequest(http.MethodPut, "/", nil)
	w := httptest.NewRecorder()
	sendResponseHeadersHandler(w, req)

	res := w.Result()
	h := res.Header
	assert.NotNil(t, h)

	assert.Equal(t, 0, len(h), h)

}
