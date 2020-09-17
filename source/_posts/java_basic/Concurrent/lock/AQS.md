---
title: 锁实现的核心-AQS
categories:
  - - java基础
    - 并发编程
    - 锁
tags:
  - 锁
  - java基础
  - 并发编程
abbrlink: 3276667042
date: 2020-09-07 16:07:51
updated: 2020-09-07 16:07:51
---

在`ReentrantLock`和`ReentrantReadWriteLock`中的内部类`Sync`都是实现了`AbstractQueuedSynchronizer`这个抽象类,

`AbstractQueuedSynchronizer`很好的分离了用户的关注点, 用户一般只需要使用由`Lock`接口提供的方法, 不需要关注线程如何唤醒, 如何抢占锁等内容

后面我们深入的理解一下`AbstractQueuedSynchronizer`这个东西, 看看他的结构是怎么样的, 是如何做到唤醒, 等待, 阻塞等作用的

<!-- more -->

//TODO
