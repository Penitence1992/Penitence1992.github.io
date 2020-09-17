---
title: Java集合-LinkedList
categories:
  - - java基础
    - 集合
tags:
  - java基础
  - 集合
  - List
abbrlink: 2325262503
date: 2020-09-01 15:13:43
---

通过`双向链表`实现了List和Deque的接口方法, 是一个有序列表, 允许插入Null元素
查找指定索引的操作, 将通过开头或者结尾开始进行遍历, 知道指定的索引为止

LinkedList是一个线程不安全的集合类

性能: 

- 随机读慢 ---> 基于链表的实现, 因此随机读取某个索引的时候, 需要由头或者尾开始遍历, 直到指定索引因此时间复杂度为O(n)

- 删除较快----> 基于链表实现, 只需要在该位置重新组织链的指针即可移除元素所以时间复杂度为O(1)

- 新增操作----> 当使用`add(obj)`方法, 时间复杂度为1, 当使用add(index, element)的时候最坏为O(n)

<!-- more -->
## 源码阅读

> 在LinkedList中, 因为使用了链表, 所以不存在容量的问题, 所以这里没有发现默认容量

- 链表的节点是一个私有的内部类Node来实现的, 主要属性就3个, 本体属性, 前一个节点指针, 下一个节点指针

```java
private static class Node<E> {
    E item;
    Node<E> next;
    Node<E> prev;

    Node(Node<E> prev, E element, Node<E> next) {
        this.item = element;
        this.next = next;
        this.prev = prev;
    }
}
```

- 有两个构造函数, 默认构造函数和传入一个集合的函数, 有参构造函数主要调用了addAll(index, Collection)方法

执行前, 会把Collection转换为数组, 因为对数组执行遍历操作是最快的, 链接的时候会把前指针和固定指针放置到(index-1)和(index)的位置上
然后把元素拼接到前指针上, 最后把添加的元素最后的一个节点和固定指针进行关联

```java
public boolean addAll(int index, Collection<? extends E> c) {
    // 数组越界检查
    checkPositionIndex(index);

    Object[] a = c.toArray();
    int numNew = a.length;
    if (numNew == 0)
        return false;
    
    //获取插入位置上的前后两个节点, 如果再末尾插入, 则当前的指针指向null的节点
    // succ理解为标记固定指针, 操作的时候都是通过前指针pred进行链接, 最后把pred和succ链接
    Node<E> pred, succ;
    if (index == size) {
        succ = null;
        pred = last;
    } else {
        succ = node(index);
        pred = succ.prev;
    }

    for (Object o : a) {
        @SuppressWarnings("unchecked") E e = (E) o;
        Node<E> newNode = new Node<>(pred, e, null);
        // 如果插入的位置为头部, 则pred指针为null, 所以把指针执行新节点,
        // 后续拼接整个链
        if (pred == null)
            first = newNode;
        else
            pred.next = newNode;
        pred = newNode;
    }
    
    // 如果插入末尾, 则succ的指针为null, 因此把尾指针放到新的位置上
    if (succ == null) {
        last = pred;
    } else {
        //把固定的指针和拼接后的链进行关联
        pred.next = succ;
        succ.prev = pred;
    }

    size += numNew;
    modCount++;
    return true;
}
```

- indexOf, contains, remove方法

因为使用了链表, 因此这些方法都是需要遍历的, 因此时间复杂度为O(n)

- get,set, add(index, element)这些方法都不复杂, 但是需要遍历, 因为内部使用的是双向链表, 因此获取的时候, 会先计算由头部还是由尾部进行遍历

node是用到的查找节点的方法, 通过计算索引所在半区的方式来查找最近的遍历方向
```java
Node<E> node(int index) {
    // assert isElementIndex(index);

    if (index < (size >> 1)) {
        Node<E> x = first;
        for (int i = 0; i < index; i++)
            x = x.next;
        return x;
    } else {
        Node<E> x = last;
        for (int i = size - 1; i > index; i--)
            x = x.prev;
        return x;
    }
}
```

- 其他暂时为发现太多的区别, 主要的操作也是由对数组变成了对链表, 链表的修改操作好处是, 不需要频繁的复制数组, 可以减少空间的使用

## 方法调用时间复杂度

- Deque中提供的方法, 都是时间复杂度为O(1)的, 这是队列的性质决定的, 只能取头或者尾的数据

- add(element), size方法的时间复杂度为O(1)

- add(index,element), remove(index), get(index), set(index, element),indexOf, lastIndexOf等操作, 都需要遍历, 时间复杂度为O(n)