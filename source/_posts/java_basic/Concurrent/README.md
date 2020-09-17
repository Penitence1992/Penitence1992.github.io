---
title: 并发编程基础概念
categories:
  - - java基础
    - 并发编程
tags:
  - java基础
  - 并发编程
abbrlink: 2189593687
date: 2020-09-02 17:12:51
update: 2020-09-09 10:45:46
---

在CPU核心数量越来越多的硬件条件下, 并发是利用多cpu核新的方式, 能够更加充分的发挥硬件的性能和提高网站的响应速度

同时在此之下也会引入了新的难题, 主要就是数据的一致性的问题, 后续将围绕这个问题展开说明, 讲解在Java中, 如何安全的进行并发编程


<!-- more -->

## 两个核心

- JMM内存模型

- Happens-before原则

## 三大概念

1. 原子性

2. 有序性

3. 可见性


    
## java内存模型

Java内存模型(Java Memory Model)是为了屏蔽各种不同硬件和操作系统的内存访问差异提出的, 为了实现Java程序在各种平台下都能达到一致的访问目的的抽象

![JMM模型](/image/java内存模型.jpg)


## Happens-before

> [原文](https://en.wikipedia.org/wiki/Happened-before), 摘自wiki
>
> [Java内存模型之happens-before](https://www.cnblogs.com/chenssy/p/6393321.html) 
>
> [Java内存模型以及happens-before规则](https://juejin.im/post/6844903600318054413)

在JDK5以后, JMM就使用happens-before的概念来阐述多线程之间的内存可见性。

> 在JMM中，如果一个操作执行的结果需要对另一个操作可见，那么这两个操作之间必须存在happens-before关系。
>
> In Java specifically, a happens-before relationship is a guarantee that memory written to by statement A is visible to statement B, that is, that statement A completes its write before statement B starts its read.

happens-before原则定义如下：

1. 如果一个操作happens-before另一个操作，那么第一个操作的执行结果将对第二个操作可见，而且第一个操作的执行顺序排在第二个操作之前。


2. 两个操作之间存在happens-before关系，并不意味着一定要按照happens-before原则制定的顺序来执行。如果重排序之后的执行结果与按照happens-before关系来执行的结果一致，那么这种重排序并不非法。

```
下面是happens-before原则规则：

1. 程序次序规则：一个线程内，按照代码顺序，书写在前面的操作先行发生于书写在后面的操作；
2. 锁定规则：一个unLock操作先行发生于后面对同一个锁额lock操作；
3. volatile变量规则：对一个变量的写操作先行发生于后面对这个变量的读操作；
4. 传递规则：如果操作A先行发生于操作B，而操作B又先行发生于操作C，则可以得出操作A先行发生于操作C；
5. 线程启动规则：如果线程A执行操作ThreadB.start()（启动线程B），那么A线程的ThreadB.start()操作happens-before于线程B中的任意操作。
6. 线程中断规则：对线程interrupt()方法的调用先行发生于被中断线程的代码检测到中断事件的发生；
7. 线程终结规则：线程中所有的操作都先行发生于线程的终止检测，我们可以通过Thread.join()方法结束、Thread.isAlive()的返回值手段检测到线程已经终止执行；
8. 对象终结规则：一个对象的初始化完成先行发生于他的finalize()方法的开始；
```

所以我们在并发编程的时候, 可以根据上面的规则来判断代码块是否线程安全, 后续依次详细了解一下规则

### 1. 程序次序规则

```java
void init() {
    int a = 1;
    int b = a;
}
```

这两个代码处理同一线程内执行的, 因此可以确保b的值是等于1等, 这是JMM内严格要求的, 重排序不能改变程序运行的结构, 所以在单个线程内执行, b结果必定为1

### 2. 锁定规则

锁定原则说的是, 锁的unlock操作, 必须先于lock操作执行, 因此, unlock和lock操作是不允许重排序的, 例如

```java
class HappensBeforeLock {
    private int value = 0;

    public synchronized int getValue() {
        int a = 1;
        int b = 2;
        return value;
    }

    public synchronized void setValue(int value) {
        this.value = value;
    }
}
```
像上述代码, 在不同线程中运行, 是能确定发生的规则的,如果线程a执行`getValue`,线程b执行`setValue`,
如果b先于a执行, 那么必定是执行完`setValue`之后再执行线程a的`getValue`,
但是`synchronized`内的执行是可以被重排序的, 如`getValue`中的a,b的赋值是可以重拍的

### 3. volatile变量规则

volatile变量之前的写操作(包括共享变量的写), 会优先于volatile变量之后的读操作,
如下, `initialized`变量, 以及之前的共享变量修改, 都会在线程b中的`initialized`之后可见, 更多的请看 {% post_link java_basic/Concurrent/volatile 深入理解volatile %}

![volatile变量规则](/image/volatile变量规则.jpg)

```java

// 摘取自: 深入理解Java虚拟机(第三版本 P447)

Map configOptions;
char[] configText;
volatile boolean initialized = false;

//线程a执行
configOptions = new HashMap();
configText = readConfig();
handleConfig(configText, configOptions);
initialized = true;

// 线程b执行
while(!initialized){
    sleep();
}

doSomeWithConfig();
```

### 4. 传递规则

这个是比较容易理解的, 即是操作`a`->`b`, `b`->`c`, 则`a`->`c`

例如:

```java
int a = 1;
int b = a;
int c = b;
```
根据传递规则, 可以得到, `a`->`c`这样的结论, 传递规则是可以结合别的原则一起来结合使用

### 5. 线程启动规则

调用线程的`start`方法之前的所有共享变量将会同步到主内存中, 新线程创建后, 将会由主内存获取共享变量数据

### 6. 线程中断规则

> 对线程interrupt()方法的调用先行发生于被中断线程的代码检测到中断事件的发生；

线程a对共享变量执行了写操作, 并且调用了b线程的`interrupt()`方法, 此时,b线程接收到中断事件的时候, 所有共享变量已经写入到主存,
并且线程b可以获取到共享变量的最新值, 所以a对共享变量的操作, 对b线程中断事件发生时候有可见性, 线程b可以使用`interrupted`方法来检查中断

例子代码如下, 这样输出的内容, 永远是3和true
```java
HappenBefore before = new HappenBefore();

Thread t2 = new Thread(() -> {
    while (!Thread.interrupted());
    System.out.println(before.getA());
    System.out.println(before.isDone());
});

Thread t1 = new Thread(() -> {
    long current = System.currentTimeMillis();
    while (System.currentTimeMillis() - current <= 100);
    before.setA(3);
    before.setDone(true);
    t2.interrupt();
});

t2.start();
t1.start();
```
### 7. 线程终结规则

> 线程中所有的操作都先行发生于线程的终止检测，我们可以通过Thread.join()方法结束、Thread.isAlive()的返回值手段检测到线程已经终止执行；

和线程中断规则类似, 线程a对共享变量执行了操作, 然后线程b调用了a线程的`join`等方法的时候, 当线程a结束以后, 数据会马上写入到主存, 并且线程b的
工作内存也会刷新

```java
Thread t1, t2;
t1 = new Thread(() -> {
    long current = System.currentTimeMillis();
    while (System.currentTimeMillis() - current <= 100);
    before.setA(3);
    before.setDone(true);
});

t2 = new Thread(() -> {
    try {
        t1.join();
        System.out.println("done");
        System.out.println(before.getA());
        System.out.println(before.isDone());
    } catch (InterruptedException e) {
        // t2线程接收到中断事件
    }
});

t2.start();
t1.start();
```