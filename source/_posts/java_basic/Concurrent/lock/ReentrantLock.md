---
title: 重入锁
categories:
  - - java基础
    - 并发编程
    - 锁
tags:
  - 锁
  - java基础
  - 并发编程
abbrlink: 2889379724
date: 2020-09-07 13:55:51
updated: 2020-09-07 13:55:51
---
# ReentrantLock

> [ReentrantLock(Java Doc)](https://docs.oracle.com/javase/8/docs/api/java/util/concurrent/locks/ReentrantLock.html) 可重入锁

可重入锁特性:
    
- 可重入
- 排他锁
- 根据初始化对象的时候绝对是公平还是非公平锁

> ps: tryLock方法未设置超时时间的时候, 会破坏公平性设置, 即会使用不公平的方式来获取锁
>
> 公平锁只会保证锁的公平性, 但是不保证cpu调度的公平性问题

`ReentrantLock`内部只是维护了一个`sync`字段, 该字段的类`Sync`实现了`AbstractQueuedSynchronizer`,基本所有的锁操作
 都是使用`Sync`的方法, 因此我们主要看的也是`Sync`里面的方法
 
<!-- more -->


### 构造函数

`ReentrantLock`的构造函数有两个, 默认无参数创建的是一个非公平的锁, `ReentrantLock(boolean fair)`传入`true`可以创建公平锁
非公平锁为内部的`NonfairSync`来实现, 公平锁为内部类`FairSync`实现
```java
public ReentrantLock() {
    sync = new NonfairSync();
}

public ReentrantLock(boolean fair) {
    sync = fair ? new FairSync() : new NonfairSync();
}
```

### 不公平锁相关代码

我们摘取出`lock`方法大概的整个流程加以说明:

```java
final void lock() {
    // 使用CAS的方式尝试获取锁, 当state为0表示该锁未被线程获取, 获取成功后, 这是owner为当前线程
    if (compareAndSetState(0, 1))
        setExclusiveOwnerThread(Thread.currentThread());
    else
        acquire(1);
}

public final void acquire(int arg) {
    // 先尝试获取锁, 获取成功则退出, 失败则加入队列, 并且执行中断
    if (!tryAcquire(arg) &&
        acquireQueued(addWaiter(Node.EXCLUSIVE), arg))
        selfInterrupt();
}

protected final boolean tryAcquire(int acquires) {
    return nonfairTryAcquire(acquires);
}

final boolean nonfairTryAcquire(int acquires) {
    final Thread current = Thread.currentThread();
    int c = getState();
    // 通过此时刚好锁被释放, 则尝试获取锁, 不进入阻塞队列
    if (c == 0) {
        if (compareAndSetState(0, acquires)) {
            setExclusiveOwnerThread(current);
            return true;
        }
    }
    // 如果当前线程拥有锁, 则计算器+1
    else if (current == getExclusiveOwnerThread()) {
        int nextc = c + acquires;
        if (nextc < 0) // overflow
            throw new Error("Maximum lock count exceeded");
        setState(nextc);
        return true;
    }
    return false;
}
```

整个的流程如下:

1. 如果当前锁未被获取, 则置state为1, 并且设置owner为当前线程
2. 如果锁已经被拥有了, 则执行`acquire`方法来尝试获取锁
3. `nonfairTryAcquire` 为非公平锁获取锁的主要代码, 当获取锁的时候, 如果刚好锁被释放, 则尝试直接获取锁
4. 如果当前锁未被释放, 则判断当前线程是否为拥有该锁的线程, 如果是, 则把计算器加1, 这也是可重入锁的实现

### 公平锁相关代码

公平锁只是重新实现了`tryAcquire`方法, 不再调用`nonfairTryAcquire`方法

```java
protected final boolean tryAcquire(int acquires) {
    final Thread current = Thread.currentThread();
    int c = getState();
    if (c == 0) {
        if (!hasQueuedPredecessors() &&
            compareAndSetState(0, acquires)) {
            setExclusiveOwnerThread(current);
            return true;
        }
    }
    else if (current == getExclusiveOwnerThread()) {
        int nextc = c + acquires;
        if (nextc < 0)
            throw new Error("Maximum lock count exceeded");
        setState(nextc);
        return true;
    }
    return false;
}

public final boolean hasQueuedPredecessors() {
    // The correctness of this depends on head being initialized
    // before tail and on head.next being accurate if the current
    // thread is first in queue.
    Node t = tail; // Read fields in reverse initialization order
    Node h = head;
    Node s;
    return h != t &&
        ((s = h.next) == null || s.thread != Thread.currentThread());
}
```

对比`tryAcquire`和`nonfairTryAcquire`主要是多了一个`hasQueuedPredecessors`的判断,
可以看到该方法主要做一件事情：主要是判断当前线程是否位于同步队列中的第一个。如果是则返回true，否则返回false。