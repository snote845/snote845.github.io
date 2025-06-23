---
layout: post
title: "Android dex 加载流程"
date: 2025-06-20 19:00:00 +0800
categories: [Android, dex, oat,vdex,odex]
tags: [Android, dex, oat, vdex, odex]
---

### Apk 中 dex，vdex，odex 文件的加载过程

Android apk 安装在到设备系统上时，dex2oat 会根据 dex 先生成vdex 与 oat 文件，执行时会同时加载到内存中，其中 vdex 是用来进行数据校验和元数据加载，oat 是优化后的机器指令合集，其中 odex 是 Android5.0 时的 oat 文件称呼。此时 ArtMethod 会存储所有的 dex 方法指令逻辑，如果 oat 中有对应的映射指令，会优先走 oat 中的机器指令，如果 oat 中没有对应的地址指令，会解释执行 dex 中的代码，在此过程中JIT会记录高频执行的类代码，已优化执行效率。当系统更新或应用更新时，oat 需要重新生成。

#### 基本概念
1. .dex 文件 (Dalvik Executable)
   * 本质： 应用程序的 Dalvik 字节码文件，是 Java/Kotlin 源代码编译成 .class 文件后，再通过 dx (Dalvik Executable) 或 d8 (Dexer) 工具转换而成的。
   * 位置： 通常位于 APK 文件内部（APK 本质是 ZIP 压缩包）。一个 APK 可以包含一个或多个 .dex 文件（classes.dex, classes2.dex, classes3.dex 等），这是为了应对 Android 65536 方法数限制而引入的多 Dex 机制。
   * 用途： 它是应用程序的原始“代码”，是 ART 或 Dalvik VM 执行的基础。
2. .odex 文件 (Optimized Dalvik Executable)
   * 历史： 主要与 Dalvik 虚拟机 (Android 4.4 KitKat 及更早版本) 相关。
   * 生成： Dalvik 使用 dexopt 工具在应用安装时对 .dex 文件进行优化。这些优化包括字节码重排序、验证和一些预连接，以加快 Dalvik VM 的解释执行速度。
   * 特点： .odex 文件是独立于 APK 存在的，通常位于 /data/dalvik-cache 或其他系统优化目录下。它不是真正的机器码，仍然是 Dex 字节码格式，只是优化过的。.odex 文件通常会包含它所依赖的 Dex 文件的校验和，以确保其与原始 Dex 及依赖环境匹配。
   * 在 ART 中的延续： 即使在 ART 时代 (Android 5.0+)，你仍然可能看到以 .odex 结尾的文件。但是，在 ART 下，这些 .odex 文件实际上是 .oat 文件的别名或特定命名约定。它们是 dex2oat 工具生成的 AOT 编译结果，而不是 Dalvik 时代的优化 Dex 字节码。
3. .oat 文件 (Ahead-Of-Time Compiled)
   * 本质： 主要与 Android Runtime (ART) (Android 5.0 Lollipop 及更高版本) 相关。.oat 文件是一种 ELF (Executable and Linkable Format) 文件，内部包含了将 Dex 字节码编译为设备原生机器码的结果，以及原始 Dex 字节码的副本（Android 7.0 之前），或者指向原始 Dex 文件的引用（Android 8.0 Oreo 及之后，原始 Dex 通常在 .vdex 文件中）。
   * 生成： ART 使用 dex2oat 工具在应用安装时（或后台、更新时）将 .dex 文件 AOT (Ahead-Of-Time) 编译成设备 CPU 架构特定的机器码。
   * 位置： 通常位于应用的沙箱目录下的 oat/ 文件夹中，例如 /data/app/com.your.app-1/oat/arm64/base.odex (这个 .odex 扩展名实际上指向的是 .oat 文件)。
   * 用途： ART 运行时可以直接加载并执行 .oat 文件中的原生机器码，从而显著提高应用的启动速度和运行时性能，减少运行时的解释和 JIT (Just-In-Time) 编译开销。

### 执行时如何找到对应文件来执行的？
Android 运行时（ART）查找和加载 .oat / .odex 文件的过程是一个复杂但有序的机制，主要由 ClassLoader 和 ART 内部的优化文件管理模块协同完成：

1. PackageManager / installd 服务：

* 当应用安装时，PackageManager 会调用 installd 服务，后者负责调用 dex2oat 对 APK 中的 .dex 文件进行 AOT 编译，并将生成的 .oat / .odex 文件存放在预期的位置（通常是 /data/app/<package\_name>-X/oat// 目录下）。
* 这个过程会记录 .oat 文件与原始 .dex 文件（及其所在的 APK 路径）的映射关系。

2. ClassLoader 初始化：

* 当应用进程启动时，Zygote 进程会 fork 出新的应用进程。
* 应用的主 ClassLoader（通常是 PathClassLoader）会被初始化。
* PathClassLoader 内部持有一个 DexPathList 对象，DexPathList 包含了多个 Element，每个 Element 代表一个可加载的 Dex 源（可以是 APK 文件本身，也可以是独立的 Dex/Jar 文件）。
* PathClassLoader 会根据 APK 的路径（例如 /data/app/com.your.app-1/base.apk）来构造其 DexPathList。

3. ART 运行时查找 .oat 文件：

* 当 ClassLoader 尝试加载某个类时，ART 运行时会在其内部机制中尝试查找对应的 .oat 文件。
* ART 会根据应用程序的 APK 路径和内部的缓存/约定，去预期的位置查找对应的 .oat / .odex 文件。例如，对于 /data/app/com.your.app-1/base.apk，它会尝试查找 /data/app/com.your.app-1/oat//base.odex。
* ART 会校验 .oat 文件的完整性以及它所依赖的原始 Dex 文件（通过校验和）是否匹配。如果校验通过，ART 会选择加载 .oat 文件。

4. 加载逻辑：

* 如果找到了有效的 .oat 文件，ART 会直接从 .oat 文件中加载并执行编译好的原生机器码。
* 如果 .oat 文件不存在、校验失败或损坏，ART 可以选择回退到解释执行 .dex 字节码，或者使用 JIT (Just-In-Time) 编译。在现代 Android 版本中，JIT 是非常普遍的，它会在运行时将热点代码编译成机器码以提高性能，并将这些编译结果缓存起来以供后续使用（配置文件引导编译 Profile-Guided Compilation）。
* 对于多 Dex 情况： 如果原始 APK 包含 classes.dex, classes2.dex 等，那么 dex2oat 也会为每个 Dex 文件生成对应的 .oat 文件（例如 base.odex, base2.odex），并且 DexPathList 会包含指向这些 Dex 源的 Element。ART 会根据类所在的原始 Dex 文件来查找对应的 .oat 文件。

### Odex/Oat 文件运行时会被直接加载到内存中吗？
是的，.oat 文件在运行时会被直接加载到内存中。

具体来说：

1. 内存映射 (Memory Mapping)： ART 运行时通常会使用内存映射（mmap 系统调用）的方式，将 .oat 文件映射到进程的虚拟地址空间。这意味着文件内容不会被完整地拷贝到 RAM 中，而是当需要访问 .oat 文件中的特定部分（如代码、数据）时，系统才按需从磁盘加载到物理内存。
2. 直接执行机器码： 由于 .oat 文件是 ELF 格式，内部包含了原生机器码，一旦被映射到内存，ART 就可以直接跳转到并执行这些机器码，而无需再进行字节码解释或 JIT 编译（对于被 AOT 编译的部分）。
3. 共享内存： 对于系统框架的 .oat 文件（如 boot.oat），它们甚至可以在多个应用进程之间共享内存映射，进一步节省系统资源。
4. VDEX 文件 (Android 8.0 Oreo+): 从 Android 8.0 开始，ART 将原始 Dex 字节码的副本从 .oat 文件中剥离出来，放入单独的 .vdex 文件中。.oat 文件只包含 AOT 编译后的机器码和一些元数据。这样做的目的是让 .oat 文件更小，并可能为将来的只读分区上的 Dex 优化提供便利。但在加载时，ART 依然会加载 .oat 并关联其对应的 .vdex 文件。

#### 总结：
* dex 是原始字节码，oat (.odex 在 ART 时代) 是它的原生机器码编译产物。

* odex (Dalvik时代)： 优化过的 Dex 字节码，是 Dalvik VM 解释执行的产物。在Android5.0 之后.dex 已经被oat 替代。后缀是.odex 实质上是 oat 文件。
* vdex(Android 8.0)：存储 dex 验证信息和元数据，用于首次加速时的启动过程。
* oat (ART时代)： Dex 字节码 AOT 编译后的原生机器码，通常以 .odex 扩展名存储，是 ART 直接执行的产物。包含的文件和机器止逆阀。

