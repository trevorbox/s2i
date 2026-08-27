package com.example.demo;

import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.resttestclient.TestRestTemplate;
import org.springframework.boot.resttestclient.autoconfigure.AutoConfigureTestRestTemplate;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.core.env.Environment;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;
import org.springframework.test.context.TestPropertySource;

import java.nio.file.Files;
import java.nio.file.Path;
import java.util.UUID;

import static org.assertj.core.api.Assertions.assertThat;

@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@AutoConfigureTestRestTemplate
@TestPropertySource(properties = "hello.server.port=0")
class DrainLifecycleTests {

	private static final Path DRAIN_FLAG = Path.of(
			System.getProperty("java.io.tmpdir"),
			"spring-boot-demo-drain-" + UUID.randomUUID());

	@DynamicPropertySource
	static void drainFlagFile(DynamicPropertyRegistry registry) {
		registry.add("app.drain-flag-file", DRAIN_FLAG::toString);
	}

	@Autowired
	private TestRestTemplate restTemplate;

	@Autowired
	private Environment environment;

	@Autowired
	private DrainFlagHealthIndicator drainFlagHealthIndicator;

	@AfterEach
	void deleteDrainFlag() throws Exception {
		Files.deleteIfExists(DRAIN_FLAG);
	}

	@Test
	void gracefulShutdownProperties_matchNativeSidecarBudget() {
		assertThat(environment.getProperty("server.shutdown")).isEqualTo("graceful");
		assertThat(environment.getProperty("spring.lifecycle.timeout-per-shutdown-phase")).isEqualTo("30s");
		assertThat(drainFlagHealthIndicator.flagFile()).isEqualTo(DRAIN_FLAG);
	}

	@Test
	void liveAndReady_areUpWhenDrainFlagIsAbsent() {
		ResponseEntity<String> live = restTemplate.getForEntity("/live", String.class);
		ResponseEntity<String> ready = restTemplate.getForEntity("/ready", String.class);
		assertThat(live.getStatusCode()).isEqualTo(HttpStatus.OK);
		assertThat(ready.getStatusCode()).isEqualTo(HttpStatus.OK);
		assertThat(live.getBody()).contains("UP");
		assertThat(ready.getBody()).contains("UP");
	}

	@Test
	void ready_returns503WhenDrainFlagExists_butLiveStaysUp() throws Exception {
		Files.createFile(DRAIN_FLAG);
		ResponseEntity<String> ready = restTemplate.getForEntity("/ready", String.class);
		ResponseEntity<String> live = restTemplate.getForEntity("/live", String.class);
		ResponseEntity<String> actuatorReady = restTemplate.getForEntity(
				"/actuator/health/readiness", String.class);
		ResponseEntity<String> actuatorLive = restTemplate.getForEntity(
				"/actuator/health/liveness", String.class);
		assertThat(ready.getStatusCode()).isEqualTo(HttpStatus.SERVICE_UNAVAILABLE);
		assertThat(actuatorReady.getStatusCode()).isEqualTo(HttpStatus.SERVICE_UNAVAILABLE);
		assertThat(live.getStatusCode()).isEqualTo(HttpStatus.OK);
		assertThat(actuatorLive.getStatusCode()).isEqualTo(HttpStatus.OK);
	}

	@Test
	void sleep_holdsThenReturnsOk() {
		ResponseEntity<String> response = restTemplate.getForEntity("/sleep?seconds=0.05", String.class);
		assertThat(response.getStatusCode()).isEqualTo(HttpStatus.OK);
		assertThat(response.getBody()).contains("slept");
	}

}
