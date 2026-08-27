package com.example.demo;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest;
import org.springframework.test.web.servlet.MockMvc;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@WebMvcTest(controllers = LifecycleController.class)
class LifecycleControllerTest {

	@Autowired
	private MockMvc mockMvc;

	@Test
	void sleep_returnsOkAndCapsExcessiveDuration() throws Exception {
		mockMvc.perform(get("/sleep").param("seconds", "0.05"))
				.andExpect(status().isOk())
				.andExpect(jsonPath("$.slept").isNumber())
				.andExpect(jsonPath("$.requestedSeconds").value(0.05));
	}

}
