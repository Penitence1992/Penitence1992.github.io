---
title: 认识Jdk8中的HashMap
categories:
  - - java基础
    - 集合
tags:
  - java基础
  - 集合
  - Map
abbrlink: 509483648
date: 2020-09-09 15:57:59
---

在Jdk8中, 对HashMap进行了改进, 改进的点主要有:

1. 当`hash`碰撞之后写入链表的长度超过了阈值(默认为8)并且`table`的长度不小于64(否则扩容一次)时，链表将会转换为**红黑树**, 当节点个数少于6的时候, 会退化为链表

2. Jdk8中插入由链表尾部插入, 因此`resize`的时候仍然保持原有的顺序, 同时修改了`resize`的过程, 解决并发下的死锁隐患

3. JDK1.7存储使用Entry数组， JDK8使用Node或者TreeNode数组存储

后面我们深入去了解HashMap的源码内容.

> ps: 为什么计算HashCode的时候需要使用31 ? 答曰: 如果使用偶数, 做乘法会导致位移运行, 如果溢出的话会导致信息修饰,
> 31有个很好的性能, 用位移和减法来代替乘法运算, 即: 31 * i == (i << 5） - i

<!-- more -->

## HashMap和TreeMap

HashMap也常和TreeMap进行比较(HashTable 在后面一句不推荐使用了, 这里就不说了), 这里将大概的不同说一下:

1. HashMap使用 `链表+数组` or `红黑树进行存储`, HashTable使用`红黑树`

2. HashMap的`Key`和`Value`都允许为`Null`, key为null的时候, hashCode为0, HashTable的key不允许为null

3. TreeMap比HashMap多实现一个`NavigableMap`的接口,该接口也扩展了`SortedMap`, 可以自定义`Comparator`来实现排序

> //TODO 待补充

## 详细阅读

### HashMap的简介

![HashMap类图](/image/HashMap简单类图.jpg)

HashMap继承了`AbstractMap`然后实现了`Map`,`Cloneable`,`Serializable`3个接口

因此我们使用的主要操作都是来自`Map`接口提供的操作

### 源码内容

我们先看看HashMap定义的静态变量

```java
// 默认容量为16
static final int DEFAULT_INITIAL_CAPACITY = 1 << 4; // aka 16

// 最大容量 2的30次方
static final int MAXIMUM_CAPACITY = 1 << 30;

// 默认负载因子
static final float DEFAULT_LOAD_FACTOR = 0.75f;

// 树化阈值
static final int TREEIFY_THRESHOLD = 8;

// 退化阈值
static final int UNTREEIFY_THRESHOLD = 6;

// 最小树化容量, 当扩容后容量大于该值的时候才转换为红黑树, 这是为了防止是选择扩容还是进行转换添加的参数
static final int MIN_TREEIFY_CAPACITY = 64;
```

根据上面的变量定义可以知道面试的时候常问的一些基础问题, 负载因子为0.75, 容量为16, 树化阈值为8, 树化容量为64,
当`HashMap`的`size > 容量*负载因子`的时候会发生扩容


#### 有趣的方法`tableSizeFor`

在`HashMap`中的签名为`static final int tableSizeFor(int cap)`, 是为了计算一个数的最近2的幂次数

```java
static final int tableSizeFor(int cap) {
    int n = cap - 1;
    n |= n >>> 1;
    n |= n >>> 2;
    n |= n >>> 4;
    n |= n >>> 8;
    n |= n >>> 16;
    return (n < 0) ? 1 : (n >= MAXIMUM_CAPACITY) ? MAXIMUM_CAPACITY : n + 1;
}
```

在Java中, 一个`int`类型用了4字节, 共32bit, 计算过程可以理解如下:

```
cap           = 0000 1000 0000 0000 0000 0000 0000 0001
n = cap - 1   = 0000 1000 0000 0000 0000 0000 0000 0000
n |= n >>> 1  = 0000 1100 0000 0000 0000 0000 0000 0000
n |= n >>> 2  = 0000 1111 0000 0000 0000 0000 0000 0000
n |= n >>> 4  = 0000 1111 1111 0000 0000 0000 0000 0000
n |= n >>> 8  = 0000 1111 1111 1111 1111 0000 0000 0000
n |= n >>> 16 = 0000 1111 1111 1111 1111 1111 1111 1111
return n + 1  = 0001 0000 0000 0000 0000 0000 0000 0000
```

这样经过5次的右移+或操作, 可以将所有bit位置换为1, 然后通过最后的+1实现翻倍, 得到2的幂的结果

#### 我们看看put方法

```java
public V put(K key, V value) {
    return putVal(hash(key), key, value, false, true);
}
```
可以看到调用的是putVal方法, 会先对k执行一次hash操作

```java
static final int hash(Object key) {
    int h;
    return (key == null) ? 0 : (h = key.hashCode()) ^ (h >>> 16);
}
```
这里的hash计算的时候, 取了key的高位和本身进行了一个异或运算, 作者说着是因为如何hash变化集中在高位, 则可能会发生一直冲突的场景,
因此作者将高位变化散播到低位来避免这种情况, 这是在速度, 实用性等衡量之后的实现, 同时在达到一定情况下, 将会使用树来处理冲突

下面是put方法的核心内容, `putVal`方法, 这个方法可能需要拆成几部分来说明

##### 完整代码
