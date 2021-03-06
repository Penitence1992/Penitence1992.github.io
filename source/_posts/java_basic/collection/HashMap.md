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
updated: 2020-09-18 17:39:31
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

> ps: 看到有文章说定义容量的时候不要定义非2次幂的数量, 在初始化的时候`tableSizeFor`方法会计算该树最近接的2次幂的数
>
> 也就是说如果你初始化的容量不是2次幂的数, 会变成最接近的2次幂的数
>
> ps2: 为什么MAXIMUM_CAPACITY会是 1 << 30 呢?
> 
> 因为当扩容的时候, 使用的是 cap << 1 来实现, 如果当容量超过MAXIMUM_CAPACITY, 假设为 1 << 31的时候, 会发现这次左移会超过int的最大值


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

这是`putVal`方法的完整代码

```java
final V putVal(int hash, K key, V value, boolean onlyIfAbsent,
                   boolean evict) {
    Node<K,V>[] tab; Node<K,V> p; int n, i;
    if ((tab = table) == null || (n = tab.length) == 0)
        n = (tab = resize()).length;
    if ((p = tab[i = (n - 1) & hash]) == null)
        tab[i] = newNode(hash, key, value, null);
    else {
        Node<K,V> e; K k;
        if (p.hash == hash &&
            ((k = p.key) == key || (key != null && key.equals(k))))
            e = p;
        else if (p instanceof TreeNode)
            e = ((TreeNode<K,V>)p).putTreeVal(this, tab, hash, key, value);
        else {
            for (int binCount = 0; ; ++binCount) {
                if ((e = p.next) == null) {
                    p.next = newNode(hash, key, value, null);
                    if (binCount >= TREEIFY_THRESHOLD - 1) // -1 for 1st
                        treeifyBin(tab, hash);
                    break;
                }
                if (e.hash == hash &&
                    ((k = e.key) == key || (key != null && key.equals(k))))
                    break;
                p = e;
            }
        }
        if (e != null) { // existing mapping for key
            V oldValue = e.value;
            if (!onlyIfAbsent || oldValue == null)
                e.value = value;
            afterNodeAccess(e);
            return oldValue;
        }
    }
    ++modCount;
    if (++size > threshold)
        resize();
    afterNodeInsertion(evict);
    return null;
}
```

---

我们先看前面两句

```java
Node<K,V>[] tab; Node<K,V> p; int n, i;
if ((tab = table) == null || (n = tab.length) == 0)
    n = (tab = resize()).length;
```

当table为null或者table的大小为0的时候, 会触发一次`resize`方法, 该方法主要是初始化或者扩容的时候调用, 在这里是用于初始化的

这里计算的`n`表示当前数组的容量

然后接下来的`if-else`则是比较重要的内容, 我们先说`if`

```java
if ((p = tab[i = (n - 1) & hash]) == null)
    tab[i] = newNode(hash, key, value, null);
else {
    ...
}
```

这里是使用数组容量和hash值进行与运算, 得到存放的数组的下标, 然后位置上没有数据, 则直接初始化一个节点放进去就可以了

> ps: 所以这里知道hash的时候为什么要把高位和低位做运算了, 否则一个hash值只有高位改变的话, 则会出现严重的hash冲突

而`else`则表示当前hash冲突了, 为了解决这种冲突, 1.8以前是通过链表的形式来把冲突位置上的节点连起来的

```java
if (p.hash == hash &&
    ((k = p.key) == key || (key != null && key.equals(k))))
    e = p;
else if (p instanceof TreeNode)
    e = ((TreeNode<K,V>)p).putTreeVal(this, tab, hash, key, value);
else {
    for (int binCount = 0; ; ++binCount) {
        if ((e = p.next) == null) {
            p.next = newNode(hash, key, value, null);
            if (binCount >= TREEIFY_THRESHOLD - 1) // -1 for 1st
                treeifyBin(tab, hash);
            break;
        }
        if (e.hash == hash &&
            ((k = e.key) == key || (key != null && key.equals(k))))
            break;
        p = e;
    }
}
```

这里面会先判断, 当前的key在是否为重复的可以, 如果是, 那就好办了, 直接跳过到后面的处理即可, 但是万一不是呢

那就会先判断是不是`TreeNode`, 如果是, 则表示当前存放的以及是一棵树了, 使用`TreeNode`的`putTreeVal`方法

否则表示当前还是链表的形式, 然后会开始遍历链表, 我们知道, 

```java
for (int binCount = 0; ; ++binCount) {
    // 一直遍历, 直到链表尾巴, 然后会初始化为一个节点, 当链表长度大于8的时候, 会尝试`treeifyBin`方法
    if ((e = p.next) == null) {
        p.next = newNode(hash, key, value, null);
        if (binCount >= TREEIFY_THRESHOLD - 1) // -1 for 1st
            treeifyBin(tab, hash);
        break;
    }
    // 判断数组的key是否存在, 存在的话则会跳出循环, 进行后续的处理
    if (e.hash == hash &&
        ((k = e.key) == key || (key != null && key.equals(k))))
        break;
    p = e;
}
```

这里有个判断`TREEIFY_THRESHOLD - 1`, 也就是常说的当链表长度大于8的时候, 会变成红黑树, 但是并没有那么简单, 我们后续再去看

后续的`if`,主要是处理key重复的情况

```java
if (e != null) { // existing mapping for key
    V oldValue = e.value;
    if (!onlyIfAbsent || oldValue == null)
        e.value = value;
    afterNodeAccess(e);
    return oldValue;
}
```

然后会判断容量是否达到了扩容的阈值, 是的话则会触发`resize()`方法扩容


#### resize

上面多次说到resize方法, 这次我们来看看他的主要内容吧

```java
final Node<K,V>[] resize() {
    Node<K,V>[] oldTab = table;
    int oldCap = (oldTab == null) ? 0 : oldTab.length;
    int oldThr = threshold;
    int newCap, newThr = 0;
    if (oldCap > 0) {
        if (oldCap >= MAXIMUM_CAPACITY) {
            threshold = Integer.MAX_VALUE;
            return oldTab;
        }
        else if ((newCap = oldCap << 1) < MAXIMUM_CAPACITY &&
                 oldCap >= DEFAULT_INITIAL_CAPACITY)
            newThr = oldThr << 1; // double threshold
    }
    else if (oldThr > 0) // initial capacity was placed in threshold
        newCap = oldThr;
    else {               // zero initial threshold signifies using defaults
        newCap = DEFAULT_INITIAL_CAPACITY;
        newThr = (int)(DEFAULT_LOAD_FACTOR * DEFAULT_INITIAL_CAPACITY);
    }
    if (newThr == 0) {
        float ft = (float)newCap * loadFactor;
        newThr = (newCap < MAXIMUM_CAPACITY && ft < (float)MAXIMUM_CAPACITY ?
                  (int)ft : Integer.MAX_VALUE);
    }
    threshold = newThr;
    @SuppressWarnings({"rawtypes","unchecked"})
        Node<K,V>[] newTab = (Node<K,V>[])new Node[newCap];
    table = newTab;
    if (oldTab != null) { ... }
    return newTab;
}
```

我们先把`if (oldTab != null)`这段收起来, 先看外面的, 前面的过程主要为如下的流程:

1. 判断旧容量是否为0, 如果为0表示已经初始化完成了

    1.1  如果旧容量已经超过最大容量, 则不进行扩容并且设置阈值, 直接返回旧表
    
    1.2  没超过最大容量, 则新容量扩大一倍, 然后阈值也增大1倍
    
2. 剩下两个条件这是针对初始化的了
   
    2.1 `else if (oldThr > 0)` 表示设置了设置初始容量的, 则直接使用
    
    2.2 如果没有设置, 则使用默认的容量`16`, 还有负载因子`0.75`来计算

3. 然后就会初始化一个新的大小的数组赋值给了`table`变量

----

我们再来看看`if (oldTab != null)`这个代码块里面的内容, 这里面主要就是处理扩容后对数据的处理

```java
for (int j = 0; j < oldCap; ++j) {
    Node<K,V> e;
    if ((e = oldTab[j]) != null) {
        oldTab[j] = null;
        if (e.next == null)
            newTab[e.hash & (newCap - 1)] = e;
        else if (e instanceof TreeNode)
            ((TreeNode<K,V>)e).split(this, newTab, j, oldCap);
        else { // preserve order
            Node<K,V> loHead = null, loTail = null;
            Node<K,V> hiHead = null, hiTail = null;
            Node<K,V> next;
            do {
                next = e.next;
                if ((e.hash & oldCap) == 0) {
                    if (loTail == null)
                        loHead = e;
                    else
                        loTail.next = e;
                    loTail = e;
                }
                else {
                    if (hiTail == null)
                        hiHead = e;
                    else
                        hiTail.next = e;
                    hiTail = e;
                }
            } while ((e = next) != null);
            if (loTail != null) {
                loTail.next = null;
                newTab[j] = loHead;
            }
            if (hiTail != null) {
                hiTail.next = null;
                newTab[j + oldCap] = hiHead;
            }
        }
    }
}
```