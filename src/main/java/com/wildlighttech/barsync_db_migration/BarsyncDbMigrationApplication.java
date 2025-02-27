package com.wildlighttech.barsync_db_migration;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;
import org.springframework.boot.autoconfigure.flyway.FlywayAutoConfiguration;

@SpringBootApplication(exclude = FlywayAutoConfiguration.class)
public class BarsyncDbMigrationApplication {

	public static void main(String[] args) {
		SpringApplication.run(BarsyncDbMigrationApplication.class, args);
	}

}
