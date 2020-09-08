---
title: 字节码层面看看synchronized的实现
date: 2020-09-07 11:27:51
categories:
 - [java基础, 并发编程, 锁]
tags:
 - 锁
 - java基础
 - 并发编程
 - 字节码
---

今天我们由字节码层面来看看`synchronized`的实现

关于class文件的字节码具体内容可以看{% post_link JVM/ClassStruct 类文件结构 %}

## 描述

从语法上讲，Synchronized可以把任何一个非null对象作为"锁"，在HotSpot JVM实现中，锁有个专门的名字：`对象监视器（Object Monitor）`。

synchronized 是java中提供的一个同步关键字, 可以作用在以下区域:

- 实例方法 
- 静态方法
- 方法体内

synchronized 的特性为:

- 排他锁
- 重入锁
- 非公平锁

<!-- more -->

## 方法体内使用


测试代码如下:

```java
public class LockTest {
    public void testLock() {
        synchronized (this) {
            System.out.println("call");
        }
    }
}
```
编译以后, 我们使用`javap`来查看字节码内容, `javap -c LockTest`

我们摘取方法`testLock`的内容

```

public void testLock();
    Code:
       0: aload_0
       1: dup
       2: astore_1
       3: monitorenter
       4: getstatic     #5                  // Field java/lang/System.out:Ljava/io/PrintStream;
       7: ldc           #6                  // String call
       9: invokevirtual #7                  // Method java/io/PrintStream.println:(Ljava/lang/String;)V
      12: aload_1
      13: monitorexit
      14: goto          22
      17: astore_2
      18: aload_1
      19: monitorexit
      20: aload_2
      21: athrow
      22: return
    Exception table:
       from    to  target type
           4    14    17   any
          17    20    17   any
```

可以看到, jvm实现`synchronized`是通过`monitorenter`和`monitorexit`两个指令, 这里监控的实例对象为`this`

同时代码段17-21是编译的时候加进去的, 这是为了确保`synchronized`方法内出现异常的时候, 也可以正常的释放锁, 确保不会进入死锁的情况

## 实例方法上使用

代码例子:

```java
public synchronized void setUsername(String username) {
    this.username = username;
}
```

然后通过命令`javap -verbose Domain`来查看字节码, 同样的,我们摘取`setUsername`的字节码来说明

```
  public synchronized void setUsername(java.lang.String);
    descriptor: (Ljava/lang/String;)V
    flags: ACC_PUBLIC, ACC_SYNCHRONIZED
    Code:
      stack=2, locals=2, args_size=2
         0: aload_0
         1: aload_1
         2: putfield      #2                  // Field username:Ljava/lang/String;
         5: return
      LineNumberTable:
        line 15: 0
        line 16: 5
      LocalVariableTable:
        Start  Length  Slot  Name   Signature
            0       6     0  this   Lcn/cityworks/honeycomb/database/manager/Domain;
            0       6     1 username   Ljava/lang/String;
    MethodParameters:
      Name                           Flags
      username
```

我们可以看到, 当使用`synchronized`来修饰实例方法以后, 方法的访问标志`flags`中添加了`ACC_SYNCHRONIZED`这个标记,
当方法调用的时候, 检查到`ACC_SYNCHRONIZED`这个标记, 线程则会获取`monitor`对象,在实例方法中, 监控的对象为`this`实例本身


## 静态方法上使用

java测试代码如下:

```java
public synchronized static Domain from(String username) {
    return new Domain();
}
```

然后通过命令`javap -verbose Domain`来查看字节码
```
public static synchronized cn.cityworks.honeycomb.database.manager.Domain from(java.lang.String);
    descriptor: (Ljava/lang/String;)Lcn/cityworks/honeycomb/database/manager/Domain;
    flags: ACC_PUBLIC, ACC_STATIC, ACC_SYNCHRONIZED
    Code:
      stack=2, locals=1, args_size=1
         0: new           #5                  // class cn/cityworks/honeycomb/database/manager/Domain
         3: dup
         4: invokespecial #6                  // Method "<init>":()V
         7: areturn
      LineNumberTable:
        line 23: 0
      LocalVariableTable:
        Start  Length  Slot  Name   Signature
            0       8     0 username   Ljava/lang/String;
    MethodParameters:
      Name                           Flags
      username
```
可以看到, 和实例方法是类似的, 区别在于, 获取监控对象的时候, 获取的是Class对象, 而不是实例对象, 相当于一个全局锁