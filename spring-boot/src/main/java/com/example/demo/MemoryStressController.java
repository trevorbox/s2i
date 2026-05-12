package com.example.demo;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;

import java.util.ArrayList;
import java.util.List;
import java.util.Map;

/**
 * Demo endpoints for heap pressure. For intentional OOM, start the JVM with:
 * <pre>
 *   -XX:+HeapDumpOnOutOfMemoryError -XX:HeapDumpPath=/path/to/dump.hprof
 * </pre>
 */
@RestController
public class MemoryStressController {

	private static final int CHUNK_BYTES = 1024 * 1024;

	private static final long MIN_RESERVE_BYTES = 1024 * 1024L;

	/** Retained allocations from the last {@code /api/memory/fill-heap} call. */
	private static final List<byte[]> FILL_HOLD = new ArrayList<>();

	/** Minimum headroom requested; exposed for tests (same package). */
	static long effectiveReserve(long reserveBytes) {
		return Math.max(MIN_RESERVE_BYTES, reserveBytes);
	}

	/**
	 * Allocates heap until only {@code reserveBytes} of headroom remains below {@link Runtime#maxMemory()},
	 * without intentionally triggering {@link OutOfMemoryError}. Each call clears prior retentions from
	 * this endpoint, then fills again.
	 */
	@GetMapping("/api/memory/fill-heap")
	public synchronized Map<String, Object> fillHeap(
			@RequestParam(name = "reserveBytes", defaultValue = "33554432") long reserveBytes) {
		long reserve = effectiveReserve(reserveBytes);

		FILL_HOLD.clear();
		Runtime rt = Runtime.getRuntime();

		long allocated = 0;
		while (true) {
			long max = rt.maxMemory();
			long used = rt.totalMemory() - rt.freeMemory();
			long headroom = max - used;
			if (headroom <= reserve + CHUNK_BYTES) {
				break;
			}
			FILL_HOLD.add(new byte[CHUNK_BYTES]);
			allocated += CHUNK_BYTES;
		}

		long usedAfter = rt.totalMemory() - rt.freeMemory();
		return Map.of(
				"status", "filled",
				"reserveBytesRequested", reserve,
				"bytesAllocatedThisCall", allocated,
				"retainedChunks", FILL_HOLD.size(),
				"maxMemoryBytes", rt.maxMemory(),
				"approxUsedHeapBytes", usedAfter);
	}

	/**
	 * Exhausts the Java heap until {@link OutOfMemoryError}. With JVM options enabled, the VM writes a
	 * heap dump and exits (or the thread dies, depending on configuration):
	 * <pre>
	 *   -XX:+HeapDumpOnOutOfMemoryError -XX:HeapDumpPath=/path/to/dump.hprof
	 * </pre>
	 * Replace {@code /path/to/dump.hprof} with a writable path (directory or full .hprof file path).
	 */
	@GetMapping("/api/memory/trigger-oom")
	public void triggerHeapOutOfMemory() {
		List<byte[]> sink = new ArrayList<>();
		while (true) {
			sink.add(new byte[CHUNK_BYTES]);
		}
	}
}
