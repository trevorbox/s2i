package com.example.demo;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.Map;

/**
 * Demo trace: Istio's HTTP span, then {@code work.authorize},
 * {@code work.lookup-order}, and {@code work.price}, with {@code enduser.id}
 * when the caller sent baggage or {@code X-End-User}.
 */
@RestController
class WorkController {

	private final WorkService workService;

	WorkController(WorkService workService) {
		this.workService = workService;
	}

	@GetMapping("/api/work")
	Map<String, Object> work(@RequestParam(name = "sku", defaultValue = WorkService.DEFAULT_SKU) String sku) {
		return this.workService.perform(sku);
	}

}
