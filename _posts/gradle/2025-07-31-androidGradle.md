---
layout: post
title: "Gradle 在 Android 中的插件版本对应关系"
date: 2025-07-31 19:00:00 +0800
categories: [Android, gradle]
tags: [Android, Tinker, gradle]
---


开发时总是会遇到Android Studio 与 Gradle/JDK/Kotlin 需要对应关系，所以在这里做个总结。 

Android 对应 Gradle 插件版本，8.x 以上 [官网](https://developer.android.com/build/releases/gradle-plugin?buildsystem=ndk-build&hl=zh-cn#updating-gradle "Android Gradle plugin version") 

|插件版本|所需的最低 Gradle 版本|
| :-----: | :-----: |
|8.11|8.13|
|8.10|8.11.1|
|8.9|8.11.1|
|8.8|8.10.2|
|8.7|8.9|
|8.6|8.7|
|8.5|8.7|
|8.4|8.6|
|8.3|8.4|
|8.2|8.2|
|8.1|8.0|
|8.0|8.0|

旧版本 8.x 以下

|插件版本|所需的 Gradle 版本|
| :-----: | :-----: |
|7.4|7.5|
|7.3|7.4|
|7.2|7.3.3|
|7.1|7.2|
|7.0|7.0|
|4.2.0+|6.7.1|
|4.1.0+|6.5+|
|4.0.0+|6.1.1+|
|3.6.0 - 3.6.4|5.6.4+|
|3.5.0 - 3.5.4|5.4.1+|
|3.4.0 - 3.4.3|5.1.1+|
|3.3.0 - 3.3.3|4.10.1+|
|3.2.0 - 3.2.1|4.6+|
|3.1.0+|4.4+|
|3.0.0+|4.1+|
|2.3.0+|3.3+|
|2.1.3 - 2.2.3|2.14.1 - 3.5|
|2.0.0 - 2.1.2|2.10 - 2.13|
|1.5.0|2.2.1 - 2.13|
|1.2.0 - 1.3.1|2.2.1 - 2.9|
|1.0.0 - 1.1.3|2.2.1 - 2.3|



Gradle 对应的 JDK 版本 [官网](https://docs.gradle.org/current/userguide/compatibility.html#java)

|Java version|Support for toolchains|Support for running Gradle|
| :-----: | :-----: | :-----: |
|8|N/A|2.0|
|9|N/A|4.3|
|10|N/A|4.7|
|11|N/A|5.0|
|12|N/A|5.4|
|13|N/A|6.0|
|14|N/A|6.3|
|15|6.7|6.7|
|16|7.0|7.0|
|17|7.3|7.3|
|18|7.5|7.5|
|19|7.6|7.6|
|20|8.1|8.3|
|21|8.4|8.5|
|22|8.7|8.8|
|23|8.10|8.10|
|24|8.14|8.14|
|25|N/A|N/A|



Kotlin 需要对应搭配的 AGP 版本[官网](https://developer.android.com/build/kotlin-support?hl=zh-tw)

|Kotlin version|Required AGP version|Required D8 and R8 version|
| :-----: | :-----: | :-----: |
|1.3|4.1|2.1.86|
|1.4|7.0|3.0.76|
|1.5|7.0|3.0.77|
|1.6|7.1|3.1.51|
|1.7|7.2|3.2.47|
|1.8|7.4|4.0.48|
|1.9|8.0|8.0.27|
|2.0|8.5|8.5.10|
|2.1|8.6|8.6.17|
|2.2|8.10|8.10.21|



Android Studio兼容版本 [官网](https://developer.android.com/build/releases/gradle-plugin?buildsystem=ndk-build&hl=zh-cn#updating-gradle "Android Gradle plugin version") 


|Android Studio version|Required AGP version|
| :----- | :-----: |
|Narwhal Feature Drop | 2025.1.2|4.0-8.12|
|Narwhal | 2025.1.1|3.2-8.11|
|Meerkat Feature Drop | 2024.3.2|3.2-8.10|
|Meerkat | 2024.3.1|3.2-8.9|
|Ladybug Feature Drop | 2024.2.2|3.2-8.8|
|Ladybug | 2024.2.1|3.2-8.7|
|Koala Feature Drop | 2024.1.2|3.2-8.6|
|Koala | 2024.1.1|3.2-8.5|
|Jellyfish | 2023.3.1|3.2-8.4|
|Iguana | 2023.2.1|3.2-8.3|
|Hedgehog | 2023.1.1|3.2-8.2|
|Giraffe | 2022.3.1|3.2-8.1|
|Flamingo | 2022.2.1|3.2-8.0|



