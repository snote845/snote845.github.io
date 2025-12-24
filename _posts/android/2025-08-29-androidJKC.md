---
excerpt: 由于业务模块中用到了 C++/java/kotlin 等不同语言，在接入 Google 支付时，强制要求使用协程调用，由于我们的业务模块原因，这不得不使用到协程与 C++ 的交互调用。为了使用时不会出现理解错误导致使用问题，做了做下梳理。同时，也引发了我的一个思考，如果一个 java 线程，协程，C...
layout: post
title: "Android Java/kotlin/C++混编的思考"
date: 2025-08-29 19:00:00 +0800
categories: [Java, Kotlin, C++]
tags: [协程, 线程]
---

由于业务模块中用到了 C++/java/kotlin 等不同语言，在接入 Google 支付时，强制要求使用协程调用，由于我们的业务模块原因，这不得不使用到协程与 C++ 的交互调用。为了使用时不会出现理解错误导致使用问题，做了做下梳理。
同时，也引发了我的一个思考，如果一个 java 线程，协程，C++线程，他们之间调用联系与关系是什么呢？

首先，根据交互场景分为如下场景
* Java 线程与 C++ 交互
* Java 线程与 Kotlin 协程交互
* Kotlin 协程与 C++  交互

- Java 线程 与 C++ 交互
	这是最常见的交互场景， 基本上都是如下调用声明
```java
// Java
public class NativeBridge {
    static {
        System.loadLibrary("my_native_lib");
    }
    // native方法声明
    public native void startNativeTask();
}
```

我们知道 Android 中主线程被阻塞超时 5s 会发生 ANR，那么在调用 JNI 时如果被阻塞一样会有相应的问题。
那么根据 Android 主线程调用同步和异步耗时任务可知。
-  从 Java 中调用 C++  同步线程
	如果你能 100% 确定不会产生耗时，从主线程调用是可以正常运行的（在 Android多台云测设备生产环境中跑过此方法，但不推荐，后续我们已经全量将交互的接口都放在了子线程中）
-  从 Java 中调用 C++异步线程
	虽然从 Java 中调用的是 C++ 的异步线程，但实际执行到 C++到内存分配之前还有 JNI 层的调用，所以还是不推荐使用主线程调用
所以结论很明确，全部放在子线程中交互。

那如果从 Java 调用 C++是一个同步逻辑应该怎么处理？
1.通过协程
```java
           //Dispatchers.IO 专门用于执行可能阻塞的 IO 或 JNI 操作
            val result = withContext(Dispatchers.IO) {
                //    在这个代码块里，你正处于一个后台线程！
                //    在这里安全地调用你的同步、阻塞的 C++ JNI 方法
                Log.d("Threading", "C++ call on thread: ${Thread.currentThread().name}")
                nativeProcessDataSync(data) // <--- 这是你的同步 JNI 调用
            }
```
2.通过线程池（原理是通过异步线程执行耗时任务，结束后再回调到主线程中执行）
```java
public class MyRepository {
    // 1. 创建一个线程池。用单线程的 Executor 可以保证任务按顺序执行
    private final ExecutorService executor = Executors.newSingleThreadExecutor();
    // 2. 创建一个与主线程 Looper 绑定的 Handler
    private final Handler mainHandler = new Handler(Looper.getMainLooper());

    // 回调接口，用于通知调用者
    public interface OperationCallback {
        void onSuccess(String result);
        void onError(Exception e);
    }

    public void performHeavyCppOperation(byte[] data, OperationCallback callback) {
        // 3. 将耗时任务提交给线程池
        executor.execute(() -> {
            try {
                // 4. 这部分代码在后台线程执行
                //    在这里安全地调用你的同步、阻塞的 C++ JNI 方法
                String result = nativeProcessDataSync(data); // <--- 同步 JNI 调用

                // 5. 任务完成，通过 Handler 将结果 post 回主线程
                mainHandler.post(() -> {
                    // 这部分代码将在主线程执行
                    callback.onSuccess(result);
                });

            } catch (Exception e) {
                mainHandler.post(() -> {
                    callback.onError(e);
                });
            }
        });
    }

    // 在 Activity/Fragment 的 onDestroy 时，别忘了关闭线程池
    public void cleanup() {
        executor.shutdown();
    }
    
    // C++ JNI 方法定义
    // public native String nativeProcessDataSync(byte[] data);
}
```

说了 Java 调用 C，再来看下 C 调用 Java，那么从 C层创建的这个 java 线程是什么，又该怎么理解？在 Android 中 C++创建的线程调用到 java 线程，如何理解这个创建的线程，它与 jvm 创建的线程是什么关系？

> 在Android的NDK环境中，C++代码可以使用标准C++库（如<thread>）或POSIX线程（pthread）来创建线程。这些线程是由操作系统（OS）直接创建和管理的native线程，而不是由JVM直接控制。

> 默认情况下，这样的native线程没有与JVM关联，因此它无法直接调用Java方法。因为调用Java方法需要一个有效的JNIEnv指针（JNI环境指针），而native线程一开始没有这个指针。
要让这个native线程能够调用Java方法，必须通过JNI的AttachCurrentThread函数将它“附加”（attach）到JVM。这一步会：
* 为当前线程分配一个JNIEnv指针。
* 在JVM内部创建一个对应的java.lang.Thread对象，并将其添加到主线程组（ThreadGroup）中，使其对JVM可见（如调试器中可见）。
* 附加后，这个线程就可以像JVM管理的线程一样调用Java方法（例如静态方法或实例方法）。但在线程结束前，必须调用DetachCurrentThread来 detach（分离），以释放资源并避免内存泄漏。
* 下面是 C 调用到 Java 中的一个示例

```
#include <jni.h>
#include <thread>

JavaVM* g_jvm;  // 全局JavaVM指针，在JNI_OnLoad中获取

void threadFunction() {
    JNIEnv* env = nullptr;
    if (g_jvm->AttachCurrentThread(&env, nullptr) == JNI_OK) {
        // 现在可以使用env调用Java方法
        jclass clazz = env->FindClass("com/example/MyClass");
        jmethodID method = env->GetStaticMethodID(clazz, "myMethod", "()V");
        env->CallStaticVoidMethod(clazz, method);
        
        // 结束前detach
        g_jvm->DetachCurrentThread();
    }
}

void startThread() {
    std::thread t(threadFunction);
    t.detach();  // 或join，根据需要
}

#注意：附加操作不是每次调用Java方法都做，而是线程首次需要时附加，并在结束时detach。频繁attach/detach会影响性能
```

**C++ 回调到 Java 正确通信示例：**
```java
// 这个 Handler 必须在主线程创建，或者使用 Looper.getMainLooper()
Handler mainThreadHandler = new Handler(Looper.getMainLooper());

// 这是暴露给 JNI 调用的“桥梁”方法
public void onNativeCallback(String data) {
    // 此时，你正处在那个“非托管的 C++ 线程”上
    // 千万不要在这里直接更新 UI!

    // 正确做法：把更新 UI 的任务打包成一个 Runnable，
    // 然后 post 到主线程的消息队列中。
    mainThreadHandler.post(() -> {
        // 这部分代码将会在未来的某个时刻在【主线程】上执行
        myTextView.setText(data);
    });
}
```

### Kotlin 协程与 Java线程交互
Kotlin 协程是构建在 Java 线程之上的，所以 Kotlin 协程与 Java 线程交互的原理是一样的，这里就不再赘述了。

 在上面中提到 Java 线程中如果想同步调用 C 耗时任务的同步逻辑处理中，解决方案之一就是将耗时任务放到挂起状态。

```java
// 同样是 JNI 调用的桥梁方法
fun onNativeCallback(data: String) {
    // 你仍然在那个“非托管的 C++ 线程”上
    // 使用 ViewModel 或全局的 CoroutineScope 启动一个新协程
    // 让协程调度器把它分配给一个受管理的后台线程（如 IO 线程池）
    myScope.launch(Dispatchers.IO) {
       // 这部分代码现在运行在 Kotlin 协程管理的【后台线程】上
       // 你可以在这里安全地进行文件读写、网络请求等操作
       processDataInBackground(data)
    }
}
```
Kotlin协程是构建在JVM之上的，因此它与Java线程之间的交互非常自然。

Kotlin 协程可以理解为建立在 java 线程上的一种多线程，比如 kotlin 协程调用 java 同步线程，需要将其放到后台协程（Dispatchers.IO）。
```java
// 在IO调度器中执行Java同步方法，避免阻塞主线程
lifecycleScope.launch {
    withContext(Dispatchers.IO) {
        // 调用耗时的Java方法
        myJavaObject.doSyncWork()
    }
}
```

 而Java 调用 Kotlin 协程不能直接启动一个协程，要使用**协程构建器**来封装协程逻辑。我理解应该是类似 java 线程使用一样的道理，最好你能建立一个全局的线程池来统一管理，否则协程的执行的状态以及作用域的管理都需要事先定好。（这里可以参照 Android Coroutines）
```java
// Kotlin
fun startCoroutineFromJava() {
    // 使用LifecycleScope或ViewModelScope
    viewModelScope.launch {
        // 挂起函数
        doSuspendWork()
    }
}
```

 同样，在 Kotlin 与C++ 交互过程中，和 Java 与 C++ 交互的原理是一致的，如果是耗时的任务你必须将 C++执行的任务放到 Dispaters.IO 中，如果需要 C++ 的回调，必须通过桥接 JNI 来进行，所以他的流程如下。
* 每个线程都需要一个 `JNIEnv*`。`JNIEnv*` 不能跨线程共享。
* 必须先调用 `JavaVM->AttachCurrentThread()` 来获取当前线程的 `JNIEnv*`。
* 任务完成后，必须调用 `JavaVM->DetachCurrentThread()` 来释放资源。

-----
一个值得思考的问题：
>  一个Android 应用中集成了各种三方 SDK，这些不同的 SDK 中肯定也用到了线程池或其他多线程的操作，那么对于整个应用来说如何管理这些不同 SDK 之间的线程？
