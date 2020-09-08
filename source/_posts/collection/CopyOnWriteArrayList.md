---
title: Java集合-CopyOnWriteArrayList
date: 2020-09-01 15:13:43
categories:
 - [java基础, 集合, 同步容器]
 - [java基础, 并发编程, 同步容器]
tags:
 - java基础
 - 集合
 - List
 - 并发编程
---

线程安全的集合类, 当执行`add`,`set`等修改操作的时候, 都会复制一遍数组来实现, 因此起名`CopyOnWriteArrayList`

特性:

- 当读取操作远比写入操作多的时候, 可以使用该类

- 当执行遍历等操作的时候, 会生成一个数据快照, 因此对本体的修改, 不会影响到遍历的内容

- 当对迭代器执行remove等操作的时候, 会抛出`UnsupportedOperationException`而不是`ConcurrentModificationException`异常
  

性能:

  - 和ArrayList相同, 使用`数组`作为底层数据结构, 因此具有和ArrayList的性质

<!-- more -->
## 源码阅读

- CopyOnWriteArrayList可以通过数组来初始化, 初始化的时候会copy一个数组, 来防止外部的操作对其造成修改

```java
public CopyOnWriteArrayList(E[] toCopyIn) {
    setArray(Arrays.copyOf(toCopyIn, toCopyIn.length, Object[].class));
}
```

- CopyOnWriteArrayList声明了一个[重入锁(ReentrantLock)](../Concurrent/lock/ReentrantLock.md), 因此内部都是使用这个锁来实现线程安全的

- set(index, element) 方法中可以看到,当传入值和当前值不一致的时候, 会进行一次复制, 复制后再赋值给`array`变量

```java
public E set(int index, E element) {
    final ReentrantLock lock = this.lock;
    lock.lock();
    try {
        Object[] elements = getArray();
        E oldValue = get(elements, index);
        if (oldValue != element) {
            int len = elements.length;
            Object[] newElements = Arrays.copyOf(elements, len);
            newElements[index] = element;
            setArray(newElements);
        } else {
            // Not quite a no-op; ensures volatile write semantics
            setArray(elements);
        }
        return oldValue;
    } finally {
        lock.unlock();
    }
}
```

- add方法基本一致, 都是在最外层使用`ReentrantLock`进行锁定, 然后进行操作, 保证整个操作的原子性

- remove(o, snapshot, index)这个方法有点不一样, 传入了一个snapshot的数组, 由`remove(Object o)`方法进行引用
会先在indexOf里面搜索是否存在对象, 如果存在则得到一个索引, *但是在这是, 可能因为别的更改,导致该元素被删除等*
因此在上锁后, 会重新检查索引位置的对象是否正确, 不是正确索引会重新寻找索引

```java
public boolean remove(Object o) {
    // 获取快照, 说是快照是因为看你在后续执行了add等操作, 这些操作因为都会copy, 所以不会修改到快照内容
    Object[] snapshot = getArray();
    int index = indexOf(o, snapshot, 0, snapshot.length);
    return (index < 0) ? false : remove(o, snapshot, index);
}

private boolean remove(Object o, Object[] snapshot, int index) {
    final ReentrantLock lock = this.lock;
    lock.lock();
    try {
        Object[] current = getArray();
        int len = current.length;
        // 如果快照和当前相同, 则跳过
        if (snapshot != current) findIndex: {
            int prefix = Math.min(index, len);
            for (int i = 0; i < prefix; i++) {
                if (current[i] != snapshot[i] && eq(o, current[i])) {
                    index = i;
                    break findIndex;
                }
            }
            if (index >= len)
                return false;
            // 如果相同位置没有变化, 则跳出if
            if (current[index] == o)
                break findIndex;
            index = indexOf(o, current, index, len);
            if (index < 0)
                return false;
        }
        Object[] newElements = new Object[len - 1];
        System.arraycopy(current, 0, newElements, 0, index);
        System.arraycopy(current, index + 1,
                         newElements, index,
                         len - index - 1);
        setArray(newElements);
        return true;
    } finally {
        lock.unlock();
    }
}
```