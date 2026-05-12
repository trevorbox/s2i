package com.example.demo;

import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.web.servlet.mvc.method.annotation.RequestMappingHandlerMapping;

import java.lang.reflect.Field;
import java.util.List;

import static org.assertj.core.api.Assertions.assertThat;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@WebMvcTest(controllers = MemoryStressController.class)
class MemoryStressControllerTest {

	@Autowired
	private MockMvc mockMvc;

	@Autowired
	private RequestMappingHandlerMapping requestMappingHandlerMapping;

	@AfterEach
	void tearDown() throws Exception {
		clearFillHold();
	}

	@SuppressWarnings("unchecked")
	private static void clearFillHold() throws Exception {
		Field f = MemoryStressController.class.getDeclaredField("FILL_HOLD");
		f.setAccessible(true);
		((List<byte[]>) f.get(null)).clear();
	}

	@Test
	void fillHeap_withReserveAboveMaxHeap_allocatesNothingAndReturnsOk() throws Exception {
		long reserveAboveMax = Runtime.getRuntime().maxMemory() + 1;
		mockMvc.perform(get("/api/memory/fill-heap").param("reserveBytes", String.valueOf(reserveAboveMax)))
				.andExpect(status().isOk())
				.andExpect(jsonPath("$.status").value("filled"))
				.andExpect(jsonPath("$.retainedChunks").value(0))
				.andExpect(jsonPath("$.bytesAllocatedThisCall").value(0))
				.andExpect(jsonPath("$.reserveBytesRequested").value(reserveAboveMax))
				.andExpect(jsonPath("$.maxMemoryBytes").exists())
				.andExpect(jsonPath("$.approxUsedHeapBytes").exists());
	}

	@Test
	void effectiveReserve_clampsBelowOneMegabyte() {
		assertThat(MemoryStressController.effectiveReserve(4096)).isEqualTo(1048576L);
		assertThat(MemoryStressController.effectiveReserve(1048576)).isEqualTo(1048576L);
		assertThat(MemoryStressController.effectiveReserve(2_000_000L)).isEqualTo(2_000_000L);
	}

	@Test
	void triggerOomEndpointIsRegistered() {
		assertThat(handlerMapsPath("/api/memory/trigger-oom")).isTrue();
	}

	@Test
	void fillHeapEndpointIsRegistered() {
		assertThat(handlerMapsPath("/api/memory/fill-heap")).isTrue();
	}

	private boolean handlerMapsPath(String path) {
		return requestMappingHandlerMapping.getHandlerMethods().keySet().stream().anyMatch(info -> {
			var cond = info.getPathPatternsCondition();
			if (cond == null) {
				return false;
			}
			return cond.getPatterns().stream().anyMatch(p -> p.getPatternString().equals(path));
		});
	}
}
