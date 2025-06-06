---
layout: post
title: "为什么 java 中接口可以在匿名函数中使用 new，而抽象类不可以？"
date: 2025-05-15 20:00:00 +0800
categories: [java]
tags: [java]
---

### 为什么 java 中接口可以在匿名函数中使用 new，而抽象类不可以？
在 Java 中，接口和抽象类都是用于实现抽象和多态的机制，但它们有一些关键的区别，导致接口可以在匿名内部类中使用 `new` 关键字，而抽象类不能。

### 关键区别：
1. **实例化规则**：

* **接口**：接口不能被实例化，它仅定义方法签名。
* **抽象类**：抽象类也不能被实例化，但可以包含具体方法和成员变量。

2. **匿名内部类的使用**：

* **接口**：可以创建一个匿名内部类来实现接口，并且这个匿名类会隐式实现接口的所有方法。
* **抽象类**：不能直接通过 `new` 关键字实例化抽象类，因为抽象类可能包含未实现的抽象方法。

3. **设计原因**：

* 接口在匿名内部类中使用 `new` 关键字时，实际上创建了一个实现了该接口的匿名类的实例。
* 抽象类由于可能包含已实现的方法和状态，需要更多的信息来实例化，因此不能直接在匿名内部类中使用 `new` 关键字来创建实例。

### 代码示例：
```Plain Text
// 使用接口的匿名内部类
Runnable runnable = new Runnable() {
    @Override
    public void run() {
        System.out.println("Running...");
    }
};
// 抽象类不能这样使用
// AbstractClass abstractClass = new AbstractClass() { ... }; // 编译错误
```
### 结论：
* 接口适合在匿名内部类中使用，因为它们只定义方法签名，而匿名内部类可以方便地实现这些方法。
* 抽象类由于可能包含已实现的方法和成员变量，不能直接在匿名内部类中通过 `new` 关键字实例化。

因此，Java 的设计允许在匿名内部类中使用接口，但不允许直接实例化抽象类。
