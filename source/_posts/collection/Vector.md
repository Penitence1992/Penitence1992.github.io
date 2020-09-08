---
title: Java集合-Vector
date: 2020-09-01 15:47:43
categories:
 - [java基础, 集合, 同步容器]
 - [java基础, 并发编程, 同步容器]
tags:
 - java基础
 - 集合
 - List
 - 并发编程
---

`Vector`是对应的`ArrayList`的同步实现

性能:

因为是和ArrayList的相同实现, 都是通过`数组`来实现的, 因此也和`ArrayList`一样

<!-- more -->
## 源码阅读

- Vector的初始化方法多了一个Vector(initialCapacity, capacityIncrement)

`capacityIncrement` 用于指定自动扩容的时候, 扩充容量的大小, 在ArrayList中, 是扩大当前容量的一半,当`capacityIncrement`
值为0的时候, 会翻倍扩容

- 基本所有的方法实现都添加了`synchronized`在方法签名上, 实现了一个方法级的同步锁, 因此速度会比较慢
