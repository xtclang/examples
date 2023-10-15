plugins {
    base
}

listOfNotNull(
    LifecycleBasePlugin.BUILD_TASK_NAME,
    LifecycleBasePlugin.CLEAN_TASK_NAME
).forEach { taskName ->
    val task = tasks[taskName]
    gradle.includedBuilds.forEach {
        task.dependsOn(it.task(":$taskName"))
    }
}
