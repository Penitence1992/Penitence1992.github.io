---
title: 加强型for循环和iterator
excerpt: 关于forEach循环和使用iterator循环遍历的使用场景等
categories:
  - - java基础
abbrlink: 609068559
date: 2020-08-30 13:26:38
updated: 2020-08-30 13:26:38
---
# 加强型for循环和iterator

> [加强型for循环和iterator](https://mp.weixin.qq.com/s?__biz=MzI2OTQ4OTQ1NQ==&mid=2247483952&idx=1&sn=43130fdf815970e0e12347d057c6b24f&scene=19#wechat_redirect)

## 记录

### 针对数组

针对数组使用`for-each`的时候, 和使用`for`是一样的, 通过反编译以后, 可以看到, 最终会被jvm编译
为`for`循环

#### 比较

1. `for-each`写起来比较简洁方便, 但是不能获取到当前迭代的下标索引

2. `for-each`只能实现顺序遍历


### 针对集合

> ps: 针对基于链表实现的List, LinkedList, 内部使用的是链表的结构
> 如果使用索引来进行获取数据的时候, 会由头进行一次遍历, 直到达到指定索引位置
> 因此如果要遍历链表结果的集合, 优先使用的`iterator`来进行迭代访问

1. `for-each`在jdk1.5以后被引入进来, 其本质是通过`iterator`接口来实现集合的迭代因此只要我们实现了`iterator`接口, 也可以使用`for-each`来进行迭代遍历

2. 因为遍历的时候使用了`iterator`, 所以需要注意在多线程环境中的问题,
如果在多线程环境中不注意,调用了修改集合的方法,有可能因为线程切换导致出现`ConcurrentModificationException`的异常

#### 为什么iterator会出现`ConcurrentModificationException`异常

1. ArrayList: 

