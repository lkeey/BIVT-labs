plugins {
    kotlin("jvm")
    application
}

dependencies {
    implementation("org.jetbrains.exposed:exposed-core:1.5.0")
    implementation("org.jetbrains.exposed:exposed-jdbc:1.5.0")
    implementation("org.xerial:sqlite-jdbc:3.50.2.0")
}

application {
    mainClass.set("lab07.MainKt")
}
