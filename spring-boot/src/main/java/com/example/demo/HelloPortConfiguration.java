package com.example.demo;

import org.apache.catalina.connector.Connector;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.tomcat.servlet.TomcatServletWebServerFactory;
import org.springframework.boot.web.server.WebServerFactoryCustomizer;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
class HelloPortConfiguration {

	@Bean
	WebServerFactoryCustomizer<TomcatServletWebServerFactory> helloPortConnectorCustomizer(
			@Value("${hello.server.port:11174}") int helloPort) {
		return factory -> {
			Connector connector = new Connector(TomcatServletWebServerFactory.DEFAULT_PROTOCOL);
			connector.setPort(helloPort);
			factory.addAdditionalConnectors(connector);
		};
	}

}
