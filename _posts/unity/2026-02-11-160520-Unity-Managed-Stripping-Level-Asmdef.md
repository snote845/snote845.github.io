---
excerpt: ###
layout: post
title: "Unity Managed Stripping Level 与 Asmdef"
date: 2026-02-10 20:05:20 +0800
categories: [Unity]
tags: [Unity]
---


之前在开发 Unity SDK 过程中忽略了两个文件配置，来补充一下。

>下面部分记录是采用AI 的答案进行汇总之后的总结，AI 已经如此强大，我们还有必要进行博客记录吗？下次再碰到同样的问题直接再问一次不就可以了吗？总觉得现在的 AI 还是缺少了一点什么，比如零散的知识串成系统的知识脉络，还有就是知道，理解，讲出来还是不一样的。先记录吧！

### Unity 中的两个配置
> Managed Stripping Level  
> asmdef

---

### 一、 什么是 Managed Stripping Level？

Unity 开发游戏完成后，在出包编译阶段，为减小出包体积进行的静态分析与裁剪的过程，分为以下几个级别，类似于Android中开启了资源压缩优化。

| 级别 | Android 对标 | 行为描述 | 风险指数 |
| :----------------- | :-------------------- | :---------------------------------------------------------- | :------------------------- | 
| **Disabled** | `minifyEnabled false` | **不剪裁**。所有的代码（包括你引用的库、Unity 引擎代码、系统库）全部打进包里。包体巨大。 | ⭐️ (无风险) |
| **Low** | 基础混淆 | **保守剪裁**。只剪裁**用户代码**和**插件代码**中明显不可达的代码。**Unity 引擎核心模块**和 **.NET 框架库** 基本不动。 | ⭐️⭐️ |
| **Medium** | 标准 ProGuard | **标准剪裁**。开始对 **Unity 引擎代码** 和 **.NET 框架** 下手。如果 Unity 发现你没用到 `Physics` 模块，它就把物理引擎相关的 C# 接口删了。 | ⭐️⭐️⭐️⭐️ (常用) |
| **High** | 激进模式 (R8 full) | **疯狂剪裁**。只要静态分析没扫到的代码，全部干掉。哪怕是系统底层库（System.dll）里的偏门方法也会被删。 | ⭐️⭐️⭐️⭐️⭐️ (SDK 噩梦) |

如果提供的Unity SDK 插件没有设置 Preserve 保护，以及 link.xml 配置，当游戏集成后开启了 Managed Stripping Level 为 Hight 级别，出包时如果SDK中某些C#代码没有依赖路径或需要反射调用的类接口可能不会打到包里面去。

### 原理：

Unity 使用了一个叫 **UnityLinker** 的工具（基于 Mono Linker）。

1.  **标记根节点（Roots）**：
    它从你的游戏场景（Scene）开始扫描，找到挂在 GameObject 上的脚本（MonoBehaviour）。这些脚本里的 `Start()`、`Update()` 等方法被视为“入口”。
2.  **构建引用树**：
    从入口开始，顺藤摸瓜。如果 `A.Start()` 调用了 `B.Foo()`，那么 `B` 类和 `Foo` 方法就被标记为“有用”。
3.  **一刀切**：
    扫描结束后，任何没有被标记为“有用”的代码，直接从最终的 DLL 中抹去。

这个代码标记有点像 java 中垃圾回收标记清除算法哈哈，不过一个是编译阶段一个是运行阶段。

所以 Unity 中为了解决上面代码裁剪问题，提供了下面的方案

1. [Preserve] 注解：用于精准保护类、方法、字段（特别是反射用到、Native 回调到的）。
2. link.xml 配置：用于保护第三方库（DLL）和整个 SDK 模块。
3. Assembly Definition：将 SDK 独立编译，方便一键保护。

#### 方案 1 [Preserve]注解，可与 link.xml 二选一

- 类保护

```cs
using UnityEngine.Scripting;

[Preserve] // 整个类及其所有成员都会被保留
public class MySdkCallback {
    public void OnSuccess() { ... }
}
```

- 方法保护

```cs
public class MySdkUtils {
    [Preserve] // 只有这个方法会被强制保留，类中其他未引用的方法可能被剪裁
    public void NativeCallThis() { ... }
}
```

优点：逻辑与代码在一起，维护方便（删代码时保护也跟着删了），不会随着重构（改类名）而失效。
缺点：侵入性强（源码里到处是 Attribute）；无法保护第三方 DLL（你改不了别人的源码）。

#### 方案 2 link.xml 配置，可与[Preserve]二选一

- 整个 SDK 模块都需要保留。
- 创建一个名为 link.xml 的文件（放在 Assets 任意目录下，通常放在 Assets/Plugins/ 或 SDK 根目录）

```xml
<linker>
    <!-- 1. 保护整个程序集 (Assembly) -->
    <!-- 适用于：第三方 DLL，或者你懒得细分，想保留整个库 -->
    <assembly fullname="ThirdParty.SDK.Library" preserve="all" />

    <!-- 2. 精准保护某个类 -->
    <assembly fullname="MyGame.Core">
        <!-- 保护特定类 -->
        <type fullname="MyGame.Core.Network.ResponseData" preserve="all" />

        <!-- 3. 只保护类中的特定方法 -->
        <type fullname="MyGame.Core.Utils.NativeBridge">
            <method name="OnPaymentSuccess" />
        </type>
    </assembly>
</linker>
```

优点：非侵入式（不需要改 C# 代码）；是保护第三方 DLL 的唯一方案；可以将多个保护规则集中管理。
缺点：维护成本高：如果代码重构（重命名了类或方法），忘了改 XML，保护就会静默失效，导致崩溃。
容易“过度保护”：为了省事常写 preserve="all"，导致未使用的代码也被打进包里，增加包体大小。

#### 方案 3 Assembly Definition

- SDK 相关的脚本放入一个独立的 Assembly Definition 文件中，将其编译成独立的 .dll
- 模块化管理： 配合方案 2，你可以在 AsmDef 所在的文件夹放一个 link.xml。Unity 会自动识别这个 link.xml 仅作用于该 Assembly 或与其关联。这样你的 SDK 就变成了一个自包含的模块（代码 + 保护配置），拖到别的项目里直接能用，不用担心 link.xml 丢失
- 方案 3 号结合下面的 asmdef 来做，先介绍 asmdef

优点：编译速度快；依赖清晰；非常适合 SDK 开发者发布给客户使用（模块化好）。
缺点：增加了项目管理的复杂度（需要处理程序集之间的引用关系）

================================================================================
### 二、 什么是 asmdef？

在 Unity 的早期版本中，所有脚本都会被默认编译进一个名为 `Assembly-CSharp.dll` 的庞大程序集中。随着项目变大，这会带来编译慢、代码耦合严重等问题。`.asmdef` 文件的出现就是为了解决这些问题，它是现代 Unity 项目架构的基石。

打开.asmdef就会看到这是一个json格式配置文件，主要作用是提供给Unity项目进行模块程序定义。

示例
```json
{
  "name": "Gameplay.Core",
  "rootNamespace": "Gameplay.Core",
  "references": [
    "Gameplay.Data",
    "ThirdParty.AI"
  ],
  "includePlatforms": [],
  "excludePlatforms": [],
  "allowUnsafeCode": false,
  "overrideReferences": false,
  "precompiledReferences": [],
  "autoReferenced": true,
  "defineConstraints": [],
  "versionDefines": []
}
```

---

### 一、 作用详解：为什么要用它？

`.asmdef` 的核心作用是将你的代码**分桶（Partitioning）**。

#### 1. 🚀 极速编译（Incremental Compilation）

- **没有 Asmdef**：你修改了一行代码，Unity 需要重新编译项目里那 5000 个脚本。耗时 20 秒。
- **有 Asmdef**：你把项目分成了 A、B、C 三个模块。你修改了模块 C 的代码，Unity 只需要重新编译模块 C，而 A 和 B 保持不变。耗时 1 秒。

#### 2. 🧩 强制解耦（Strict Dependency Management）

- 它在物理层面建立了一堵墙。
- 如果模块 A 没有在 `.asmdef` 中显式引用模块 B，那么 A 里面的脚本**绝对无法访问** B 里面的类。
- 这能有效防止“面条代码”，逼迫开发者写出结构清晰、依赖明确的代码。它还能防止**循环依赖**（A 引用 B，B 又引用 A，这在 Asmdef 架构下是不允许的）。

#### 3. 📱 平台与环境隔离

- **Editor 代码剥离**：你可以建立一个只在 Editor 环境下编译的 Asmdef。这样打包 APK/IPA 时，Editor 代码（如自定义 Inspector、编辑器工具）会自动被剔除，不会报错，也不占包体。
- **平台限定**：你可以编写一套只在 Android 编译的代码，和一套只在 iOS 编译的代码，通过 Asmdef 的 Platform 设置来隔离。

#### 4. 📦 模块化交付（UPM 支持）

- 如果你想制作一个 Unity Package（UPM），`.asmdef` 是必须的。它让你的插件成为一个独立的单元，用户拖进去就能用，不用担心和用户的代码冲突。

---

### 二、 配置详解：Inspector 面板完全解读

在Unity中Project创建右键Create --> Assembly Definition --> DemoSDK 

选中一个 `.asmdef` 文件，Inspector 面板中的解释如下

#### 1. Name (名称)

- 生成的 `.dll` 文件的名字。
- **建议**：使用反向域名格式，如 `com.bridge.sdk.demo`，避免冲突。

#### 2. General (通用设置)

- **Allow 'unsafe' Code**：如果你需要使用 `unsafe` 关键字（指针等），必须勾选此项。
- **Auto Referenced (自动引用)**：
  - **✅ 勾选（默认）**：Unity 默认生成的 `Assembly-CSharp` 可以直接访问你的这个库。适合游戏业务逻辑。
  - **⬜ 不勾选**：`Assembly-CSharp` 看不到你。只有显式引用了你的其他 Asmdef 才能看到你。**适合底层库或插件，防止业务层随意调用底层非公开接口。**
- **No Engine References**：勾选后不引用 `UnityEngine` / `UnityEditor`。极少用，除非你写的是纯 C# 算法库。
- **Root Namespace** (Unity 2020.2+)：设置后，脚本里不需要写 `namespace X { ... }` 包裹，Unity 编译时会自动加上。

#### 3. Define Constraints (宏定义约束)

- 这是一个“开关”。只有当这里列出的 Scripting Define Symbols 满足条件时，这个 Assembly 才会参与编译。
- **示例**：填入 `ENABLE_ADS`。只有你在 Player Settings 里定义了 `ENABLE_ADS`，这个文件夹下的广告代码才会被编译。否则就像这个文件夹不存在一样。
- 支持逻辑运算：`!ENABLE_ADS` (不存在时编译)，`UNITY_ANDROID || UNITY_IOS`。

#### 4. Assembly Definition References (引用其他 Asmdef)

- 这里决定了你的代码能“看见”谁。
- **Use GUIDs**：**强烈建议勾选**。
  - 如果不勾选，它存的是文件名。如果你重命名了引用的 Asmdef，引用就断了。
  - 如果勾选，它存的是 GUID。无论你怎么改名、移动文件，引用都不会丢。

#### 5. Assembly References (引用原生 DLL)

- 如果你的代码依赖外部的 `.dll` 文件，需要在这里勾选 `Override References` 然后把 DLL 拖进去。

#### 6. Platforms (平台设置)

- 决定这个库在哪些平台生效。
- **经典用法**：
  - **Runtime 库**：选 `Any Platform`。
  - **Editor 库**：只选 `Editor`。这是写编辑器扩展工具（MenuItem, CustomEditor）的标准做法，防止打包报错。

#### 7. Version Defines (版本定义 - 高级)

- 用于处理包依赖兼容性。
- **场景**：你的插件依赖 `Unity UI` 包。你可以设置：如果项目中存在 `com.unity.ugui` 且版本大于 `2.0`，则定义宏 `HAS_UGUI`。你的代码里就可以写 `#if HAS_UGUI` 来做兼容。

---

### 三、 使用详解：最佳实践与常见坑

#### 1. 标准项目结构（推荐）

对于一个中型以上的游戏项目，建议至少按以下方式划分：

```text
Assets/
├── Scripts/
│   ├── Core/               <-- Asmdef: Game.Core (无依赖，纯工具/底层)
│   ├── Gameplay/           <-- Asmdef: Game.Gameplay (引用 Game.Core)
│   ├── UI/                 <-- Asmdef: Game.UI (引用 Core, Gameplay)
│   └── Editor/             <-- Asmdef: Game.Editor (仅 Editor 平台，引用上述所有)
```

#### 2. SDK 开发结构（你的场景）

如果你在开发 SDK，必须遵循 **Runtime / Editor 分离** 原则：

```text
Assets/SDK/
├── Runtime/                <-- Asmdef: SDK.Runtime
│   ├── Manager.cs    (平台设置: Any Platform)
│   └── Models.cs
├── Editor/                 <-- Asmdef: SDK.Editor
│   ├── SDKSettings.cs      (平台设置: Editor Only)
│   └── BuildProcess.cs     (引用: SDK.Runtime)
```

这样用户打包游戏时，你的编辑器代码会自动消失，不会导致打包失败。

#### 3. 常见问题排查

- **问题 A：代码里提示 `The type or namespace name 'XXX' could not be found`**

  - **原因**：你在脚本 A 里用了脚本 B，但 A 所在的 Asmdef 没有引用 B 所在的 Asmdef。
  - **解决**：去 A 的 `.asmdef` Inspector 里，把 B 加到 References 列表里。

- **问题 B：循环依赖 (Cyclic Dependency)**

  - **现象**：Inspector 报错 "References X which references Y which references X"。
  - **原因**：模块 A 引用了 B，模块 B 又想引用 A。
  - **解决**：这是架构设计错误。
    1.  提取公共部分到模块 C（Base），让 A 和 B 都引用 C。
    2.  使用 **C# 委托 (Action/Func)** 或 **接口 (Interface)** 进行回调，切断物理依赖。

- **问题 C：加了 Asmdef 后，脚本在 Inspector 上丢失引用 (Script Missing)**
  - **原因**：修改 `.asmdef` 的名字或 GUID 会导致元数据变化，Unity 可能无法将旧的脚本引用映射回来。
  - **解决**：尽量在项目初期规划好，不要频繁修改 Asmdef 的名字。如果必须改，可能需要重新挂载脚本或使用文本编辑器批量替换 GUID。

#### 4. 补充技巧：`.asmref` (Unity 2020.2+)

如果你有一个巨大的模块（比如 Gameplay），你想把里面的部分文件移动到另一个文件夹整理，但不想把它们拆分成新的 DLL。

- 你可以在子文件夹里创建一个 `.asmref` 文件。
- 它的作用是：“这个文件夹下的脚本，属于那个指定的 `.asmdef`”。
- 这允许你跨文件夹组织文件，但仍然归属于同一个编译单元。

---

---

关于方案 3 **Assembly Definition (AsmDef)**，这通常是 SDK 开发者或大型项目架构师最喜欢的方案。

这里有一个重要的概念需要澄清：**在 Unity 中使用 AsmDef，不需要你手动去 Visual Studio 里点“生成”来产出一个 `.dll` 文件再拷回 Unity。**

Unity 会在后台**自动**把包含 `.asmdef` 文件的文件夹编译成一个独立的 DLL（位于项目临时缓存 `Library/ScriptAssemblies` 中）。对于使用者来说，它看起来就像是源码，但行为上像一个独立的库。

以下是具体的操作步骤，分为 **“如何创建”** 和 **“如何交付/使用”** 两部分。

---

### 第一阶段：如何创建独立的程序集 (DLL)

假设你的 SDK 代码都在 `Assets/MySDK/` 文件夹下。

#### 1. 创建 AsmDef 文件

1.  在 Unity Project 窗口中，进入你的 SDK 根目录（例如 `Assets/MySDK/`）。
2.  右键空白处 -> **Create** -> **Assembly Definition**.
3.  给文件起个名字，比如 `MyCompany.SDK`。
    - _注意：这个名字就是最终生成的 DLL 的文件名（`MyCompany.SDK.dll`）。_

#### 2. 验证生效

一旦你创建了这个文件，你会发现 Unity 会触发一次快速的编译（右下角转圈）。
此时，**该文件夹（及其子文件夹）下的所有 C# 脚本**，都会被从默认的 `Assembly-CSharp.dll` 中剥离出来，单独编译进 `MyCompany.SDK.dll` 中。

#### 3. 处理引用关系 (非常关键！)

如果你的 SDK 代码里引用了 Unity UI、TextMeshPro 或者其他第三方插件，你会发现代码突然报错了（找不到类）。
这是因为独立的 Assembly 默认**看不见**其他非全局的 Assembly。

- **操作方法**：
  1.  点击你刚才创建的 `MyCompany.SDK.asmdef` 文件。
  2.  在 Inspector 面板中，找到 **Assembly Definition References**。
  3.  点击 `+` 号，把你依赖的库拖进去（例如 `Unity.TextMeshPro`）。
  4.  点击 **Apply**。

---

### 第二阶段：如何配合防剪裁 (Stripping Protection)

既然已经独立了，我们就可以针对这个 DLL 做保护。

#### 1. 配合 link.xml (推荐)

在 `Assets/MySDK/` 文件夹下（也就是和 `.asmdef` 同级），创建一个 `link.xml` 文件：

```xml
<linker>
    <!-- 保护当前文件夹生成的这个 Assembly -->
    <assembly fullname="MyCompany.SDK" preserve="all" />
</linker>
```

#### 2. 为什么这样做很棒？

因为 Unity 有个特性：**当加载 Assembly 时，会自动加载与其同目录下的 link.xml。**
这意味着，你把保护逻辑和代码“打包”在一起了。

---

### 第三阶段：如何“拖拽使用” (交付给用户)

这一步解释了为什么说它是“模块化”的。

当你想把这个 SDK 给别的项目（或者客户）使用时：

1.  **打包**：你只需要把 `Assets/MySDK` 这个**整个文件夹**打成一个 `.unitypackage`，或者直接把文件夹复制出来。
2.  **安装**：用户只需要把这个 `MySDK` 文件夹**拖拽**进他们项目的 `Assets` 目录下的任意位置。

**发生了什么？**

1.  用户项目里的 Unity 检测到了 `MyCompany.SDK.asmdef`。
2.  Unity 自动将文件夹里的代码编译成独立的 DLL。
3.  Unity 自动读取同目录下的 `link.xml`，自动应用防剪裁规则。


### 总结：AsmDef 方案的优越性

- **如果不加 AsmDef**：你需要告诉用户“请打开你们项目的 link.xml，加上这一行...”。用户经常会忘，然后游戏上线后崩溃。
- **如果加了 AsmDef**：保护配置跟随文件夹走，用户无感知，**即插即用**。

- 目前使用的方案是，配置了Preserve与Link.xml，然后定义了.AsmDef。