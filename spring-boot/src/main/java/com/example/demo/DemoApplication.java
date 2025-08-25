package com.example.demo;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;

import reactor.core.publisher.Flux;

import java.time.Duration;
import java.time.Instant;
import java.util.Map;

@SpringBootApplication
public class DemoApplication {

	public static void main(String[] args) {
		SpringApplication.run(DemoApplication.class, args);
	}

}

@RestController
class HelloController {

    @GetMapping("/")
    Object hello() {
        return Map.of("Hi", Instant.now());
    }
}

@RestController
class ChunkedController {

    /**
     * This endpoint will stream a series of strings with a delay between each one.
     * The `produces = MediaType.TEXT_EVENT_STREAM_VALUE` is a common way to signal
     * that a server-sent event stream is being returned, which inherently uses chunked encoding.
     * The key here is returning a `Flux<String>` which is a reactive stream.
     *
     * @return A Flux of strings, each emitted after a 1-second delay.
     */
    @GetMapping(value = "/stream-data", produces = MediaType.TEXT_EVENT_STREAM_VALUE)
    public Flux<String> streamData() {
        return Flux.interval(Duration.ofSeconds(1))
                   .map(sequence -> "Data chunk number: " + sequence)
                   .take(5); // Take only the first 5 elements to stop the stream
    }


    /**
     * This is another example that shows how to return a plain text stream without
     * a specific event-stream media type. The `Flux` still forces chunked encoding.
     *
     * @return A Flux of strings, each emitted after a 1-second delay.
     */
    @GetMapping(value = "/stream-plain", produces = MediaType.TEXT_PLAIN_VALUE)
    public Flux<String> streamPlainText() {
        return Flux.just("First chunk.", "Second chunk.", "Third chunk.")
                   .delayElements(Duration.ofSeconds(1));
    }
    /**
     * This endpoint will stream a series of strings with a delay between each one.
     * The `produces = MediaType.TEXT_EVENT_STREAM_VALUE` is a common way to signal
     * that a server-sent event stream is being returned, which inherently uses chunked encoding.
     * The key here is returning a `Flux<String>` which is a reactive stream.
     *
     * @return A Flux of strings, each emitted after a 1-second delay.
     */
    @GetMapping(value = "/stream-data-dupe-te", produces = MediaType.TEXT_EVENT_STREAM_VALUE)
    public ResponseEntity<Flux<String>> streamDataDuplicate() {
        
        Flux<String> result =  Flux.interval(Duration.ofSeconds(1))
                   .map(sequence -> "Data chunk number: " + sequence)
                   .take(5); // Take only the first 5 elements to stop the stream

        return ResponseEntity.ok().header("transfer-encoding", "chunked").body(result);
    }
}
