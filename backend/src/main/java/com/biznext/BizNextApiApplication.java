package com.biznext;

import org.springframework.boot.SpringApplication;
import org.springframework.boot.autoconfigure.SpringBootApplication;

import java.io.File;

@SpringBootApplication
public class BizNextApiApplication {

    static {
        if (System.getProperty("java.net.preferIPv4Stack") == null) {
            System.setProperty("java.net.preferIPv4Stack", "true");
        }
        if (System.getProperty("jdk.net.hosts.file") == null) {
            File[] candidates = new File[] {
                    new File("hosts"),
                    new File("backend/hosts"),
                    new File("../backend/hosts"),
                    new File(System.getProperty("user.dir"), "hosts"),
                    new File(System.getProperty("user.dir"), "backend/hosts")
            };
            for (File candidate : candidates) {
                if (candidate.exists()) {
                    System.setProperty("jdk.net.hosts.file", candidate.getAbsolutePath());
                    break;
                }
            }
        }
    }

    public static void main(String[] args) {
        SpringApplication.run(BizNextApiApplication.class, args);
    }
}
