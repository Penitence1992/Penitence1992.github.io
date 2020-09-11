---
title: Java集合文章整理
categories:
  - - java基础
    - 集合
tags:
  - java基础
  - 集合
abbrlink: 96d238f4
date: 2020-09-01 15:58:17
---

主要看一下java中各种集合的源码, 同时对于不同集合的使用场景进行归纳,
并且针对不同类型集合的操作做一个时间复杂度的整理等

针对并发环境下, 又分成了`非线程安全集合`, `同步集合`, `并发集合`

其中`非线程安全集合`是线程不安全的, 无法在并发环境下使用的集合,
而`同步集合`和`并发集合`都是线程安全的, 主要区别在于实现,性能和扩展上

<!-- more -->

## jdk 1.8的新增或者修改内容

在jdk1.8中, 类比迭代器(Iterator)新增了(Spliterator)

Iterator是一个串行的迭代, 而Spliterator是一个并行的迭代器

### Iterable

- forEach(Consumer) (新增)

通过forEach的方式来封装了一次这个方法, 使得实现了Iterable的类, 可以通过lambda的方式来遍历集合

```java
default void forEach(Consumer<? super T> action) {
    Objects.requireNonNull(action);
    for (T t : this) {
        action.accept(t);
    }
}
```

- spliterator (新增)

创建一个并行迭代器, 可能主要用于给`StreamSupport`提供支持

### Collection

- removeIf(Predicate) (新增)

    `removeIf`新增在`Collection`的接口内, 默认提供了一个使用迭代器来实现的遍历删除方法
    
- stream()

    通过StreamSupport来创建一个stream流

- parallelStream()

    创建一个并行的流

## 集合框架下的接口

### Spliterator

并行迭代器, Stream都是使用该接口来构建一个Stream流, 该接口包含的方法有:

1. tryAdvance --> 对元素进行处理, 如果元素存在在处理并且返回true, 否则返回false

2. trySplit  --> 对元素进行分割, 会尽力按照1/2的数量进行分割, 返回一个新的Spliterator, 旧的Spliterator也会被修改

3. estimateSize --> 返回待处理元素

4. characteristics --> 特征

```java
public static final int ORDERED    = 0x00000010;//表示元素是有序的（每一次遍历结果相同）
public static final int DISTINCT   = 0x00000001;//表示元素不重复
public static final int SORTED     = 0x00000004;//表示元素是按一定规律进行排列（有指定比较器）
public static final int SIZED      = 0x00000040;//表示大小是固定的
public static final int NONNULL    = 0x00000100;//表示没有null元素
public static final int IMMUTABLE  = 0x00000400;//表示元素不可变
public static final int CONCURRENT = 0x00001000;//表示迭代器可以多线程操作
public static final int SUBSIZED   = 0x00004000;//表示子Spliterators都具有SIZED特性
```
## 线程不安全集合


集合的家族图谱

> ps: 图谱来源网络

![家族图谱](/image/集合家族图谱.jpg)

- {% post_link collection/ArrayList ArrayList %}

基于数组实现的列表集合, 实现了List接口, 并且实现了`RandomAccess`表示其对随机访问的优化

- {% post_link collection/LinkedList LinkedList %}

基于双向链表实现的列表, 实现了接口List和Deque

## 同步集合

读线程安全集合相关内容的时候, 可能还需要集合并发编程的思想, 包括各种的锁, 线程安全等内容理解

- {% post_link collection/Vector Vector %}

是对应的ArrayList的线程安全版本, 通过加锁等方法来实现线程安全

## 并发集合

并发相关的集合框架都位于`java.util.concurrent`下, 也就是俗称的`JUC`, juc是并发编程必须了解的内容

- {% post_link collection/CopyOnWriteArrayList CopyOnWriteArrayList %}


## 特殊集合

### BitSet

这是一个特殊的集合, 没有实现集合的基本接口, 并且提供了一些bit运算, 如 `与`, `或`, `异或`
一个基于bit位的集合