package com.example.demo;

import io.micrometer.core.instrument.MeterRegistry;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.resttestclient.TestRestTemplate;
import org.springframework.boot.resttestclient.autoconfigure.AutoConfigureTestRestTemplate;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.core.env.Environment;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.test.context.TestPropertySource;

import static org.assertj.core.api.Assertions.assertThat;

@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@AutoConfigureTestRestTemplate
@TestPropertySource(properties = "management.endpoints.web.exposure.include=health")
class DemoApplicationTests {

	@Autowired
	private TestRestTemplate restTemplate;

	@Autowired
	private Environment environment;

	@Autowired
	private MeterRegistry meterRegistry;

	@Test
	void contextLoads() {
	}

	@Test
	void applicationName_isDemo() {
		assertThat(environment.getProperty("spring.application.name")).isEqualTo("demo");
	}

	@Test
	void root_returnsOkWithHiKey() {
		ResponseEntity<String> response = restTemplate.getForEntity("/", String.class);
		assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
		assertThat(response.getBody()).isNotNull().contains("\"Hi\"");
	}

	@Test
	void healthActuator_returnsUp() {
		ResponseEntity<String> response = restTemplate.getForEntity("/actuator/health", String.class);
		assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
		assertThat(response.getBody()).isNotNull().contains("\"status\":\"UP\"");
	}

	@Test
	void meterRegistry_isAvailable() {
		assertThat(meterRegistry).isNotNull();
		assertThat(meterRegistry.getMeters()).isNotEmpty();
	}
}
