---
layout: post
title: "Gradle-plugin创建并发布到 maven 库"
date: 2025-04-30 19:00:00 +0800
categories: [Android, gradle-plugin]
tags: [Android, maven, gradle-plugin]
excerpt: >-
  在研究 Robust 框架过程中回忆了一下 gradle-plugin 的发布流程，以及发布到本地 maven 仓库的过程，从网上搜了很多文章发现无法直接使用，有些分享都过时了没有更新导致无法使用，不知道是不是大家现在越来越过于依赖 ai，分享的知识都是很大很深度的技术内容，其实日常工作更多的是...
---

> 在研究 Robust 框架过程中回忆了一下 gradle-plugin 的发布流程，以及发布到本地 maven 仓库的过程，从网上搜了很多文章发现无法直接使用，有些分享都过时了没有更新导致无法使用，不知道是不是大家现在越来越过于依赖 ai，分享的知识都是很大很深度的技术内容，其实日常工作更多的是关注细节和直接拿来实践的知识。希望能持续坚持记录和分享这些技术。

#### 开发环境
* jdk 1.8 
* gradle 4.0.2 
* gradle wrapper gradle-6.1.1-all

* macos

1.创建 module，保留 build.gradle 以及 main 下 java 与 resource 目录

2.build.gradle 设置如下

```xml
plugins {
    id 'java-gradle-plugin'
    id 'maven-publish'
}
dependencies {
    implementation gradleApi()
    implementation 'com.android.tools.build:gradle:4.0.2'
}
group = 'com.snote.gradle.plugin'
version = '1.0.0'
gradlePlugin {
    plugins {
        myPlugin {
            id = 'com.hoolai.gradle.plugin'
            implementationClass = 'com.snote.plugin.MyPlugin'
        }
    }
}
publishing {
    publications {
        mavenJava(MavenPublication) {
            from components.java
            groupId = project.group
            artifactId = 'snote-gradle-plugin'
            version = project.version
        }
    }
    repositories {
        maven {
            name = 'localRepo'
            url = layout.buildDirectory.dir("repo")
        }
    }
}
```
3. 创建自定义 Gradle 插件类实现 Plugin

```xml
public class MyPlugin implements Plugin<Project> {
    @Override
    public void apply(Project project) {
        System.out.println("==============apply==============");
    }
}
```
4. 创建META-INF/gradle-plugins 文件夹，创建插件的 \$grupId.properties,里面指向插件类

```xml
implementation-class=com.snote.plugin.MyPlugin
```
5. 插件发布成功后按照下面流程测试
6. 使用方式
   1. 在项目根目录build.gradle dependencies{...}中引入插件

```xml
    dependencies {
        classpath 'com.android.tools.build:gradle:4.0.2'
        classpath 'com.snote.gradle.plugin:hoolai-gradle-plugin:1.0.0'
    }
```
   2. 在需要使用的主 module 中引入即可

```xml
    apply plugin:'com.android.application'
    apply plugin:'maven'
    apply plugin:'com.snote.gradle.plugin'
```
