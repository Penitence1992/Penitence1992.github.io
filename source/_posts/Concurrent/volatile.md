---
title: Java关键字-volatile
date: 2020-09-02 17:28:51
categories:
 - [java基础, 并发编程]
tags:
 - java基础
 - 并发编程
---

# volatile

> https://juejin.im/post/6844903959107207175


volatile关键字只能修饰类变量和实例变量。方法参数、局部变量、实例常量以及类常量都是不能用volatile关键字进行修饰的.

就算是被volatile修饰的关键字, 也需要经历写入缓存, 缓存再写入主存的步骤, 并不会直接写入主存

<!-- more -->
 
修饰以后主要的作用有:

- 保证不同线程之间的数据可见性

    根据java的内存模型, 内存被划分为了`主内存`和`线程内存`, 线程内存中存放的是变量副本, 因此在并发修改变量的时候, 因为修改的是内存副本中的变量,
    修改的值不能及时刷新到主内存中, 同样别的内存读到的也可能是旧数据, 因此并发操作可能会导致和预期结果不一致
    
- 禁止重排序
    
    禁止被volatile变量的后面的指令放到之前去执行, 查看汇编代码会发现, volatile变量的位置会加上了一个`lock`的标志,这个作用相当于内存屏蔽,
    相当于说, 未执行完前面的步骤, 无法穿过这道屏障
    
    
由于volatile变量只能保证可见性, 在不符合以下两条规则的运算场景下, 我们仍然要通过加锁来保证原子性:

- *运算结果并不依赖变量的当前值, 或者能够确保只有单一的线程修改变量的值*

- *变量不需要其他的状态变量共同参与不变约束*

## 实现原理

> [彻底理解volatile](https://juejin.im/post/6844903601064640525)

volatile关键字在汇编层面的实现是在对变量进行写操作前,添加了一个`lock`的写屏障, 禁止后面的指令重排序到`lock`前面,
同时会将写入的数据直接由缓存写回主内存中, 同时使得别的副本内存中的缓存状态失效, 这里的`缓存一致性`主要通过`MESI协议`实现

### 查看汇编指令

可以通过`hsdis`来查看class文件的相关汇编指令,源码如下:

>   ps: 使用`hsdis`插件需要先按照一个`hsdis-amd64`的插件

```java
public class Domain {

    static volatile int i = 0;

    public static void main(String[] args) {
        i = i + 1;
    }

}
```

然后我们通过如下命令查看:
```shell
javac Domain.java
java -XX:+UnlockDiagnosticVMOptions -XX:+PrintAssembly  Domain 
```

### volatile的内存语义实现

JMM通过内存屏障来实现禁止指令的重排操作, 常见的屏障类型如下:

![内存屏障](/image/volatile/jmm内存屏障类型.jpg)

- StoreStore屏障：禁止上面的普通写和下面的volatile写重排序；
- StoreLoad屏障：防止上面的volatile写与下面可能有的volatile读/写重排序
- LoadLoad屏障：禁止下面所有的普通读操作和上面的volatile读重排序
- LoadStore屏障：禁止下面所有的普通写操作和上面的volatile读重排序


java编译器会在生成指令系列时在适当的位置会插入内存屏障指令来禁止特定类型的处理器重排序。为了实现volatile的内存语义，JMM会限制特定类型的编译器和处理器重排序，JMM会针对编译器制定volatile重排序规则表：

![重排序规则表](/image/volatile/重排序规则表.jpg)


volatile写是在前面和后面分别插入内存屏障，而volatile读操作是在后面插入两个内存屏障, 示意图:

![volatile写](/image/volatile/volatile写屏障插入.jpg)
![volatile写](/image/volatile/volatile读屏障插入.jpg)


## 硬件层面

由于CPU的数量增多, 为了让CPU处理更多任务, 提出了并行, 但是因为CPU计算速度和内存读取速度差了几个量级, 为了解决这个问题, 引入了
接近CPU计算速度的高速缓存, 这样CPU计算就不需要等待内存读写, 但是也出现了缓存数据的一致性问题

![交互图](/image/CPU内存交互流程.jpg)

除了缓存之外, 为了提供运行效率, CPU会对输入的代码进行重排序(Out-Of-Order Execution)的优化, 因此使用关键字volatile的变量,
会在执行写操作之前, 插入指令`lock addl`, 用于禁止后面的指令先于前面的执行

当写操作完成后, 会马上把缓存数据回写到主存, 并且标识副本内存中的缓存状态为I(Invalid)

### MESI协议

MESI表示了缓存行的四种状态:

- M(Modify) 表示共享数据只缓存当前CPU缓存中，并且是被修改状态，也就是缓存的数据和主内存中的数据不一致。

- E(Exclusive) 表示线程的独占状态，数据只缓存在当前的CPU缓存中，并且没有被修改

- S(Shared) 表示数据可能被多个CPU 缓存，并且各个缓存中的数据和主内存数据一致

- I(Invalid) 表示缓存已经失效