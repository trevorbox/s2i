package com.example.demo;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.resttestclient.TestRestTemplate;
import org.springframework.boot.resttestclient.autoconfigure.AutoConfigureTestRestTemplate;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.http.HttpEntity;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpMethod;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.test.context.TestPropertySource;

import static org.assertj.core.api.Assertions.assertThat;

@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@AutoConfigureTestRestTemplate
@TestPropertySource(properties = "hello.server.port=0")
class WorkControllerTest {

	private static final String SAMPLED_TRACEPARENT = "00-4bf92f3577b34da6a3ce929d0e0e4736-00f067aa0ba902b7-01";

	@Autowired
	private TestRestTemplate restTemplate;

	@Test
	void work_continuesIncomingTraceAndPrefersBaggageOverHeader() {
		HttpHeaders headers = new HttpHeaders();
		headers.set("X-End-User", "ada");
		headers.set("baggage", "enduser.id=grace");
		headers.set("traceparent", SAMPLED_TRACEPARENT);

		ResponseEntity<String> response = restTemplate.exchange(
				"/api/work?sku=widget", HttpMethod.GET, new HttpEntity<>(headers), String.class);

		assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
		assertThat(response.getBody()).isNotNull()
				.contains("\"enduser.id\":\"grace\"")
				.contains("\"traceId\":\"4bf92f3577b34da6a3ce929d0e0e4736\"")
				.contains("lookup-order")
				.doesNotContain("\"enduser.id\":\"ada\"");
	}

	@Test
	void work_readsEndUserHeaderWhenBaggageIsAbsent() {
		HttpHeaders headers = new HttpHeaders();
		headers.set("X-End-User", "ada");

		ResponseEntity<String> response = restTemplate.exchange(
				"/api/work", HttpMethod.GET, new HttpEntity<>(headers), String.class);

		assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
		assertThat(response.getBody()).isNotNull().contains("\"enduser.id\":\"ada\"");
	}

	@Test
	void work_ignoresAnEndUserHeaderThatCannotBePropagated() {
		HttpHeaders headers = new HttpHeaders();
		headers.set("X-End-User", "not a user");

		ResponseEntity<String> response = restTemplate.exchange(
				"/api/work", HttpMethod.GET, new HttpEntity<>(headers), String.class);

		assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
		assertThat(response.getBody()).isNotNull().doesNotContain("enduser.id");
	}

}
