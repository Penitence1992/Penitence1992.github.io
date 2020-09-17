---
title: 2020-09-17-使用Taints和Tolerations
tags:
  - k8s
categories:
  - - k8s
    - 资源调度
abbrlink: 3583424469
date: 2020-09-17 09:20:00
updated: 2020-09-17 09:20:00
---

## 背景

最近项目部署的时候，好像资源不太够了，然后pod运行到了跑数据库的节点上，导致节点超负荷，然后死机了。

针对这个问题，只好对现有的部署的Helm进行改造了，通过添加`Taints`和`Tolerations`来保护节点和让节点运行特定的服务

<!-- more -->

## Taints(污点)

中文翻译过来就是污点(不知道为什么叫污点), 用于排斥特定的pod。

使用`kubectl taint`命令可以给节点添加一个污点:

```shell
kubectl taint nodes k8s-master-1 [key]=[value][:[NoSchedule]]
```

这样就可以给节点添加上一个污点了, 他的键名是`key`, 值是`value`, `:`后追加的是效果(`effect`)`NoSchedule`

删除污点的话只需要key和效果即可, 例如:

```shell
kubectl taint nodes k8s-master-1 [key][:[NoSchedule]]-
```

污点的效果(effect)目前有这几类:

- NoSchedule: 不允许调度, 但是已运行在上面的pod不会被驱逐, 后续pod不允许调度到该节点上

- PreferNoSchedule: 这个值表示`尽量避免`调度到该节点上, 但是如果资源不够用的时候, 还是会调度到该节点上的, 相当于`NoSchedule`的软限制版本

- NoExecute:  表示该节点不允许调度, 同时如果有不允许的节点在这允许, 同时会被驱逐, 但是可以通过设置`tolerations`中的`tolerationSeconds`参数来设置运行停留多长时间

因为一个节点可以添加多个污点, 因此调度器处理这些污点的时候, 是通过类似过滤器一样的形式来处理的:

遍历节点的所有污点, 过滤掉和容忍度匹配的污点, 然后如果还剩下污点, 则剩下的污点决定了调度器的行为

例如:

- 如果至少存在一个`effect`为`NoSchedule`的污点, 则不会分配pod到该节点

- 如果不存在`NoSchedule`但是存在`PreferNoSchedule`, 则尽量避免分配到该节点

- 如果至少存在一个`NoExecute`, 则不会分配到节点, 并且会驱逐在节点上运行的

## Tolerations(容忍度)

`Tolerations`设置就是为了配合`Taints`来使用的, 表示该pod是能够容忍这些污点的, 例如:

```yaml
tolerations:
- key: "key1"
  operator: "Equal"
  value: "value1"
  effect: "NoSchedule"
```

它表示的是能容忍`key1=value1:NoSchedule`这个污点

同时`operator`有两个值:

- Equal : 需要配合value使用, 表示key=value必须要匹配

- Exists: 不需要value, 表示存在键值`key`就匹配了

> ps: 有个特殊情况, 例如我们需要容忍所有的污点怎么写呢??
>
> 这里的配合使用由两种特殊情况:
>
> 1. 如果`key`为空, 而且`operator`为`Exists`, 表示这个容忍度与任意的 key 、value 和 effect 都匹配，即这个容忍度能容忍任意 taint。
> 
> 2. 如果`effect`为空，则表示能容忍所有`effect`


## 1.18新增基于污点驱逐

在 k8s 1.18中, 新增功能

节点调度器会在特定情况下, 为Node节点添加污点来实现驱逐:

- `node.kubernetes.io/not-ready`: 节点未准备好, 相当于节点的`Ready`状态的值为`False`

- `node.kubernetes.io/unreachable`: 节点控制器无法访问到节点, 相当于`Ready`为`Unknow`

- `node.kubernetes.io/out-of-disk`: 节点磁盘耗尽

- `node.kubernetes.io/memory-pressure`: 存在内存压力

- `node.kubernetes.io/disk-pressure`: 磁盘压力

- `node.kubernetes.io/network-unavailable`: 节点网络不可达

- `node.kubernetes.io/unschedulable` : 节点不可调度

- `node.cloudprovider.kubernetes.io/uninitialized` : 如果 kubelet 启动时指定了一个 "外部" 云平台驱动， 它将给当前节点添加一个污点将其标志为不可用。在 cloud-controller-manager 的一个控制器初始化这个节点后，kubelet 将删除这个污点。