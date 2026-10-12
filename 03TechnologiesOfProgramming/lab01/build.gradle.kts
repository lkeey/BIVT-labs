plugins {
    base
}

tasks.register("verifyLabDocumentation") {
    group = "verification"
    description = "Checks that the Git lab documentation and report are present."
    inputs.files("README.md", "Lab01_Report_Kiryushin.docx")
    doLast {
        check(file("README.md").isFile) { "README.md is missing" }
        check(file("Lab01_Report_Kiryushin.docx").isFile) { "Word report is missing" }
    }
}
