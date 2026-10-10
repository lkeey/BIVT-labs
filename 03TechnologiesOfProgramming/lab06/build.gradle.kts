plugins {
    kotlin("jvm")
    application
}

dependencies {
    testImplementation(kotlin("test-junit5"))
    testRuntimeOnly("org.junit.jupiter:junit-jupiter-engine:5.13.4")
}

application {
    mainClass.set("lab06.MainKt")
}

tasks.test {
    useJUnitPlatform()
}
