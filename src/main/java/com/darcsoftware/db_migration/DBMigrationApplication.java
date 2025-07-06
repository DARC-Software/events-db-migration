package com.darcsoftware.db_migration;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.SpringBootConfiguration;
import org.springframework.boot.WebApplicationType;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.boot.autoconfigure.flyway.FlywayAutoConfiguration;
import org.springframework.boot.autoconfigure.jdbc.DataSourceAutoConfiguration;
import org.springframework.boot.builder.SpringApplicationBuilder;
import org.springframework.context.annotation.Import;

@SpringBootConfiguration
@Import({DataSourceAutoConfiguration.class, FlywayAutoConfiguration.class})
public class DBMigrationApplication {

	public static void main(String[] args) {

		SpringApplication application =
				new SpringApplicationBuilder(DBMigrationApplication.class)
						.web(WebApplicationType.NONE).build();

		application.run(args);
	}

}
