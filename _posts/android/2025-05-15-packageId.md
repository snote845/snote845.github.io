---
layout: post
title: "package 与 applicationId 的区别"
date: 2025-05-15 21:00:00 +0800
categories: [Android, AndroidManifest.xml]
tags: [Android]
---

### Android 中 package 与 applicationId 的理解
最近在打包时碰到了在 apk 的包名 applicationId 目录下 无法找到R\$styleable.smali 文件的问题？然后分析了一下AndroidManifest.xml 中 package 与 applicationId 区别，了解了一下两个不同的概念。

AndroidManifest.xml 中的package定义的是包结构的概念，当 apk 在编译时会将res 下资源变异后的 R 文件生成到 package 目录下，即所有的 R 资源都会在这里生成好。

applicationId 是应用的唯一 id，实际不参与包结构上的编译，仅用来为商店和手机中识别身份的唯一 id 作用。生成 apk 后，applicationId 会替代 package。

例如，若 package 为 com.example.myapp，applicationId 可设为 com.example.myapp.free，打包后 APK 的 AndroidManifest.xml 中 package 变为 com.example.myapp.free，但 R 类仍基于 com.example.myapp 生成。

这么做的好处是修改当前的 applicationId 不会影响到资源编译结构的变化，也就是更容易出多个不同applicationId 的包。

关键属性与作用

|属性/概念|描述|影响范围|
| ----- | ----- | ----- |
|AndroidManifest.xml 中的 package|源代码的 Java 包名，初始值|代码组织和 R 类生成|
|build.gradle 中的 applicationId|APK 的唯一标识符，替换最终 manifest 的 package|设备和应用商店的应用程序标识|
|build.gradle 中的 namespace|代码的包名，默认与 package 一致，可手动设置|直接决定 R 类的包名|
