---
title: 读写锁
categories:
  - - java基础
    - 并发编程
    - 锁
tags:
  - 锁
  - java基础
  - 并发编程
abbrlink: a73eaf8d
date: 2020-09-07 16:32:51
---
# ReentrantReadWriteLock

> [ReentrantReadWriteLock(Java Doc)](https://docs.oracle.com/javase/8/docs/api/java/util/concurrent/locks/ReentrantReadWriteLock.html)

特性:

- 可重入锁
- 共享锁
- 根据初始化对象的时候绝对是公平还是非公平锁

## 简述

可重入读写锁, 实现的是接口`ReadWriteLock`, 包含内部类`Sync`,`ReadLock`,`WriteLock`,`NonfairSync`, `FairSync`5个内部类

`ReentrantReadWriteLock`也是提供了公平锁和非公平锁两种实现, 分别由`Sync`的子类`NonfairSync`和`FairSync`
实现`writerShouldBlock`和`readerShouldBlock`方法来提供是否需要阻塞的判断

<!-- more -->

在`Sync`中, 我们可以看到定义了这么几个字段和方法:

```java
/*
 * Read vs write count extraction constants and functions.
 * Lock state is logically divided into two unsigned shorts:
 * The lower one representing the exclusive (writer) lock hold count,
 * and the upper the shared (reader) hold count.
 */
static final int SHARED_SHIFT   = 16;
static final int SHARED_UNIT    = (1 << SHARED_SHIFT);
static final int MAX_COUNT      = (1 << SHARED_SHIFT) - 1;
static final int EXCLUSIVE_MASK = (1 << SHARED_SHIFT) - 1;

/** Returns the number of shared holds represented in count  */
static int sharedCount(int c)    { return c >>> SHARED_SHIFT; }
/** Returns the number of exclusive holds represented in count  */
static int exclusiveCount(int c) { return c & EXCLUSIVE_MASK; }
```
根据注释我们可以看到, 这里说明了, 读锁和写锁的计数器分别由两个无符号short类型组成, 前16bit为读计数器, 后16bit为写计数器, 如图:

![读写锁计数器区](/image/读写状态区.png)

计算获取到读锁的线程的数量是通过直接无符号右移16位即可, 左侧会通过0补齐

计算获取到写锁的次数则是通过和`0000000000000000 1111111111111111`((1 << 16) - 1)进行与运算来得到

在读写锁中会发生`锁降级`

- 锁降级: 当线程获取到写锁后, 再获取读锁, 然后释放写锁, 此时该线程的锁会由写锁降级为读锁, 其他线程可以获取读锁

## 源码阅读

### 读锁获取锁

获取读锁的代码, 是通过`Sync`的`tryAcquireShared`来获取的

```java
protected final int tryAcquireShared(int unused) {
    Thread current = Thread.currentThread();
    int c = getState();
    // 计算写锁个数, 如果不为0, 并且锁的owner不是当前线程, 则返回-1表示失败
    if (exclusiveCount(c) != 0 &&
        getExclusiveOwnerThread() != current)
        return -1;
    // 获取读锁的个数
    int r = sharedCount(c);
    // 尝试获取共享锁, 获取成功则返回1, 否则尝试完整的获取共享锁的函数fullTryAcquireShared
    if (!readerShouldBlock() &&
        r < MAX_COUNT &&
        compareAndSetState(c, c + SHARED_UNIT)) {
        // 如果是第一个获取读锁, 则设置读一个读线程, 和读线程计算器置为1
        if (r == 0) {
            firstReader = current;
            firstReaderHoldCount = 1;
        } else if (firstReader == current) {
            firstReaderHoldCount++;
        } else {
            // 获取线程计算器, 如果不存在, 或者不是当前线程, 则创建一个新的线程计算器
            // 这里的cache只是为了缓存, 如果同一线程多次进入, 则可以加快获取速度
            HoldCounter rh = cachedHoldCounter;
            if (rh == null || rh.tid != getThreadId(current))
                cachedHoldCounter = rh = readHolds.get();
            else if (rh.count == 0)
                readHolds.set(rh);
            rh.count++;
        }
        return 1;
    }
    return fullTryAcquireShared(current);
}

final int fullTryAcquireShared(Thread current) {
    HoldCounter rh = null;
    for (;;) {
        int c = getState();
        // 如果存在写锁, 并且写锁的线程不是当前线程, 则获取读锁失败
        if (exclusiveCount(c) != 0) {
            if (getExclusiveOwnerThread() != current)
                return -1;
            // else we hold the exclusive lock; blocking here
            // would cause deadlock.
        // 根据策略, 如果处于排他锁, 或者公平模式下, 不处于队列第一位的,且未获取到读锁的线程将会被提出
        // 进入到等待队列中
        } else if (readerShouldBlock()) {
            // Make sure we're not acquiring read lock reentrantly
            if (firstReader == current) {
                // assert firstReaderHoldCount > 0;
            } else {
                if (rh == null) {
                    rh = cachedHoldCounter;
                    if (rh == null || rh.tid != getThreadId(current)) {
                        rh = readHolds.get();
                        if (rh.count == 0)
                            readHolds.remove();
                    }
                }
                if (rh.count == 0)
                    return -1;
            }
        }
        if (sharedCount(c) == MAX_COUNT)
            throw new Error("Maximum lock count exceeded");
        // 尝试获取读锁, 如果获取失败, 则进入循环继续获取
        if (compareAndSetState(c, c + SHARED_UNIT)) {
            // 和上部分的逻辑一直, 如果不存在读锁, 则初始化第一个读线程和计算器
            if (sharedCount(c) == 0) {
                firstReader = current;
                firstReaderHoldCount = 1;
            } else if (firstReader == current) {
                firstReaderHoldCount++;
            } else {
                if (rh == null)
                    rh = cachedHoldCounter;
                if (rh == null || rh.tid != getThreadId(current))
                    rh = readHolds.get();
                else if (rh.count == 0)
                    readHolds.set(rh);
                rh.count++;
                cachedHoldCounter = rh; // cache for release
            }
            return 1;
        }
    }
}
```

这里面有几个变量需要说明一下: 

- rh: 类`HoldCounter`, 用于存放线程获取的读锁的个数, 和实现重入锁一致的功能, 让统一线程重入的时候, 将count+1

```java
static final class HoldCounter {
    int count = 0;
    // Use id, not reference, to avoid garbage retention
    final long tid = getThreadId(Thread.currentThread());
}
```

- readHolds: 类`ThreadLocalHoldCounter`, 用于绑定`HoldCounter`到当前线程, 存放当前线程的计数器

```java
static final class ThreadLocalHoldCounter
    extends ThreadLocal<HoldCounter> {
    public HoldCounter initialValue() {
        return new HoldCounter();
    }
}
```

`fullTryAcquireShared`方法和`tryAcquireShared`有部分代码类似, 但是里面用的是一个死循环, 用于一直循环, 知道获取到
读锁为止

### 读锁释放代码

读锁释放的代码主要为下面两个: 

```
public final boolean releaseShared(int arg) {
    if (tryReleaseShared(arg)) {
        doReleaseShared();
        return true;
    }
    return false;
}

protected final boolean tryReleaseShared(int unused) {
    Thread current = Thread.currentThread();
    // 如果释放线程为第一个线程, 则直接使用firstReader和firstReaderHoldCount来进行释放
    if (firstReader == current) {
        // assert firstReaderHoldCount > 0;
        if (firstReaderHoldCount == 1)
            firstReader = null;
        else
            firstReaderHoldCount--;
    } else {
        // 通过readHolds来获取当前线程占用的线程数, 并且减少1, 如果为0, 则移除出readHolds
        HoldCounter rh = cachedHoldCounter;
        if (rh == null || rh.tid != getThreadId(current))
            rh = readHolds.get();
        int count = rh.count;
        if (count <= 1) {
            readHolds.remove();
            if (count <= 0)
                throw unmatchedUnlockException();
        }
        --rh.count;
    }
    for (;;) {
        int c = getState();
        // 减少一个读锁, 如果读锁为0, 触发释放信号
        int nextc = c - SHARED_UNIT;
        if (compareAndSetState(c, nextc))
            // Releasing the read lock has no effect on readers,
            // but it may allow waiting writers to proceed if
            // both read and write locks are now free.
            return nextc == 0;
    }
}
```

- doReleaseShared 当释放信号执行后, 唤醒后续的线程来占用锁

读锁释放, 是通过减少一个读锁计数器, 如果当前线程读锁计数器为0 , 则执行`doReleaseShared`进行信号传播

### 写锁获取代码

写锁的代码比读锁的要简单点, 这是因为写锁的实现和普通的ReentrantLock是类似的, 也是一个排他锁

```java
protected final boolean tryAcquire(int acquires) {
    Thread current = Thread.currentThread();
    int c = getState();
    // 获取写锁个数
    int w = exclusiveCount(c);
    if (c != 0) {
        // (Note: if c != 0 and w == 0 then shared count != 0)
        // 写锁为0 , c不为0, 表示存在读锁, 存在读锁无法获取写锁, 返回false
        if (w == 0 || current != getExclusiveOwnerThread())
            return false;
        if (w + exclusiveCount(acquires) > MAX_COUNT)
            throw new Error("Maximum lock count exceeded");
        // Reentrant acquire
        // 通过上面的判断, 表示当前线程是拥有锁的, 并且是重入, 因此直接设置state
        setState(c + acquires);
        return true;
    }
    // 锁未被线程占用, 根据设置来获取是否需要排队, 并且尝试通过CAS来占用锁, 成功则设置owner为当前线程
    if (writerShouldBlock() ||
        !compareAndSetState(c, c + acquires))
        return false;
    setExclusiveOwnerThread(current);
    return true;
}
```

### 写锁释放

```java
protected final boolean tryRelease(int releases) {
    if (!isHeldExclusively())
        throw new IllegalMonitorStateException();
    int nextc = getState() - releases;
    boolean free = exclusiveCount(nextc) == 0;
    if (free)
        setExclusiveOwnerThread(null);
    setState(nextc);
    return free;
}
```

写锁释放还是比较简单的, 先判断是否为独占模式, 如果不是则抛出`IllegalMonitorStateException`异常,
然后释放写锁, 当写锁全部释放以后, owner设置为null, 然后唤醒下一个线程