---
title: Java集合-ArrayList
date: 2020-09-01 14:31:43
categories:
 - [java基础, 集合]
tags:
 - java基础
 - 集合
 - List
---

基于`数组`实现的一个集合, 存放内容有序, 线程不安全, 允许插入Null元素
相对的线程安全集合为`Vector`

性能: 

- 随机读较快 ---> 基于数组, 通过下标可以直接定位到位置时间复杂度为O(1)

- 删除较慢----> 需要重新移动数组位置

- 新增操作----> 当使用`add(obj)`方法, 时间复杂度为1, 当使用add(index, element)的时候最坏为O(n)

- 频繁的插入和删除会导致数组频繁拷贝, 效率低同时消耗内存高

因此使用ArrayList的场景多为 读操作追加频繁, 替换或者插入少

<!-- more -->

## 源码阅读

- 默认容量为`10`-> `private static final int DEFAULT_CAPACITY = 10;`, 数组最大的容量为 `Integer.MAX_VALUE - 8` 或者 `Integer.MAX_VALUE` 这是因为jvm的不同, 可能导致的不同结果, 可以查看ArrayList的`hugeCapacity`方法

- 使用数组`elementData`来保存数据, 使用属性`size`来保存集合大小

- 初始化的时候可以指定容量, 如果不指定容量, 则初始的数组为空数组, 则在第一次add的时候, 才会初始化为10

```java
public ArrayList(Collection<? extends E> c) {
    // 调用Collection的toArray方法, 生成数组, 作为ArrayList的基础内容
    elementData = c.toArray();
    if ((size = elementData.length) != 0) {
        // c.toArray might (incorrectly) not return Object[] (see 6260652)
        if (elementData.getClass() != Object[].class)
            elementData = Arrays.copyOf(elementData, size, Object[].class);
    } else {
        // replace with empty array.
        this.elementData = EMPTY_ELEMENTDATA;
    }
}
```

- set方法 是直接替换掉指定位置的元素, 所以不会触发扩容

- add(element)和add(index, element), 触发扩容的时候, 计算代码主要为`int newCapacity = oldCapacity + (oldCapacity >> 1)` 所以新容量大概为旧容量的1.5倍

```java

/**
* 直接在末尾添加, 添加前会选计算数组容量, 如果容量不足会触发扩容
*/
public boolean add(E e) {
    ensureCapacityInternal(size + 1);  // Increments modCount!!
    elementData[size++] = e;
    return true;
}

/**
* 也会先计算容量, 容量不足会触发扩容, 同时, 插入前会触发一次数组的复制, 调用System.arraycopy方法复制数组,
* 复制的时候, 主要是把index下标后的元素往后移动一位, 然后再在index上设置值
*/
public void add(int index, E element) {
    rangeCheckForAdd(index);

    ensureCapacityInternal(size + 1);  // Increments modCount!!
    System.arraycopy(elementData, index, elementData, index + 1,
                     size - index);
    elementData[index] = element;
    size++;
}

private void ensureCapacityInternal(int minCapacity) {
    ensureExplicitCapacity(calculateCapacity(elementData, minCapacity));
}

// 计算最小容量, 如果elementData为空数组, 则取minCapacity或者10的最大值, 否则返回minCapacity
private static int calculateCapacity(Object[] elementData, int minCapacity) {
    if (elementData == DEFAULTCAPACITY_EMPTY_ELEMENTDATA) {
        return Math.max(DEFAULT_CAPACITY, minCapacity);
    }
    return minCapacity;
}

private void ensureExplicitCapacity(int minCapacity) {
    modCount++;
    // 当最小容量大于当前数组的长度, 则触发扩容
    // overflow-conscious code
    if (minCapacity - elementData.length > 0)
        grow(minCapacity);
}

private void grow(int minCapacity) {
    // overflow-conscious code
    int oldCapacity = elementData.length;
    // 增加当前容量的1/2的大小, 也就是扩大1.5倍
    int newCapacity = oldCapacity + (oldCapacity >> 1);
    // 如果新容量还是小于最小容量, 则直接使用最小容量
    if (newCapacity - minCapacity < 0)
        newCapacity = minCapacity;
    // 如果新容量大于了数组的最大容量, 在ArrayList中为 Integer.MAX_VALUE - 8
    if (newCapacity - MAX_ARRAY_SIZE > 0)
        newCapacity = hugeCapacity(minCapacity);
    // minCapacity is usually close to size, so this is a win:
    elementData = Arrays.copyOf(elementData, newCapacity);
}
```

- remove方法

```java
public E remove(int index) {
    rangeCheck(index);
    // 结构修改+1
    modCount++;
    // 取出需要移除的位置的值
    E oldValue = elementData(index);
    // 计算需要移动多少个元素, eg: 当size为10, 删除index为5的元素, 这表示 5后面的元素需要前移一位, 则6,7,8,9移动
    int numMoved = size - index - 1;
    if (numMoved > 0)
        System.arraycopy(elementData, index+1, elementData, index,
                         numMoved);
    // 最后一个元素设为null, 让gc工作
    elementData[--size] = null; // clear to let GC do its work

    return oldValue;
}
```

- ArrayList内部类ListItr, Itr, 并发环境下, 由于迭代和对ArrayList的内容修改,会导致modCount 和expectedModCount不一致, 然后会抛出ConcurrentModificationException异常
每个集合抛出ConcurrentModificationException的实现可能都不太一样
ListItr 扩展了Itr, 并提供了add和获取前一个元素的方法还有替换当前元素的方法

```java
private class Itr implements Iterator<E> {
    // cursor 表示下一个对象的索引
    int cursor;       // index of next element to return
    // 表示当前指向的索引, 如果执行了remove方法, 会使得该指针指向-1
    int lastRet = -1; // index of last element returned; -1 if no such
    int expectedModCount = modCount;

    Itr() {}

    public E next() {
        checkForComodification();
        int i = cursor;
        // 当为调用hasNext的时候, 直接调用next, 就有可能出现该异常
        if (i >= size)
            throw new NoSuchElementException();
        Object[] elementData = ArrayList.this.elementData;
        if (i >= elementData.length)
            throw new ConcurrentModificationException();
        cursor = i + 1;
        return (E) elementData[lastRet = i];
    }

    public void remove() {
        if (lastRet < 0)
            throw new IllegalStateException();
        checkForComodification();
        // 调用ArrayList的删除方法, 并且重新设置modCount
        try {
            ArrayList.this.remove(lastRet);
            cursor = lastRet;
            lastRet = -1;
            expectedModCount = modCount;
        } catch (IndexOutOfBoundsException ex) {
            throw new ConcurrentModificationException();
        }
    }

    // 检查表结构是否修改, 当并发环境下, 修改ArrayList的结构, 会导致modCount和expectedModCount的不同, 抛出ConcurrentModificationException的异常
    final void checkForComodification() {
        if (modCount != expectedModCount)
            throw new ConcurrentModificationException();
    }
}
```

- removeIf jdk1.8新增的方法, 用于提供一个遍历删除整个列表的方法

通过提供一个返回值为boolean的lambda表达式来判断是否需要删除该元素,
整体的思路是通过一个`BitSet`位图来标记需要删除的元素的下标位置, 当对数组遍历标记完成以后, 再执行一次删除的操作
删除的时候, 是通过前移操作, 把后面的元素覆盖掉删除的元素来实现删除的功能

```java
public boolean removeIf(Predicate<? super E> filter) {
    Objects.requireNonNull(filter);
    // figure out which elements are to be removed
    // any exception thrown from the filter predicate at this stage
    // will leave the collection unmodified
    int removeCount = 0;
    final BitSet removeSet = new BitSet(size);
    final int expectedModCount = modCount;
    final int size = this.size;
    // 标记阶段
    for (int i=0; modCount == expectedModCount && i < size; i++) {
        @SuppressWarnings("unchecked")
        final E element = (E) elementData[i];
        if (filter.test(element)) {
            removeSet.set(i);
            removeCount++;
        }
    }
    if (modCount != expectedModCount) {
        throw new ConcurrentModificationException();
    }

    // shift surviving elements left over the spaces left by removed elements
    final boolean anyToRemove = removeCount > 0;
    if (anyToRemove) {
        final int newSize = size - removeCount;
        for (int i=0, j=0; (i < size) && (j < newSize); i++, j++) {
            // 获取下一个没有被标记的bit位, 然后重新不移动或者往前移动
            i = removeSet.nextClearBit(i);
            elementData[j] = elementData[i];
        }
        // 数组后面的内容设置为null
        for (int k=newSize; k < size; k++) {
            elementData[k] = null;  // Let gc do its work
        }
        this.size = newSize;
        if (modCount != expectedModCount) {
            throw new ConcurrentModificationException();
        }
        modCount++;
    }

    return anyToRemove;
}
```

## 方法调用时间复杂度

> The size, isEmpty, get, set, iterator, and listIterator operations run in constant time. The add operation runs in amortized constant time, that is, adding n elements requires O(n) time. All of the other operations run in linear time (roughly speaking). The constant factor is low compared to that for the LinkedList implementation.

1. size, isEmpty, get, set, iterator, listIterator 都是O(1)

2. add(element)为O(1), add(index, element)最坏情况下为O(n), 详细情况后续,主要是因为执行插入操作, 需要复制一次数组, 并且把该位置后面的元素后移

3. 需要遍历的操作, 如forEach, removeIf需要O(n)的时间, removeAll会根据传入的集合的类型决定, 因为使用到了contains, 所以如果为hash表, 则为O(n), 如果为List, 则需要O(nm)