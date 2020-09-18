---
title: 2020-09-18-K8s的IPVS模式下的长连接导致的ConnectReset
date: 2020-09-18 16:55:00
updated: 2020-09-18 16:55:00
tags:
 - k8s
 - 运维
categories:
 - - k8s
   - 网络运维
---

## 背景

最近一直被告知环境中的服务会出现`Connection reset by peer`等问题，这些问题都是在k8s环境中运行的时候才会出现。

然后通过我辛苦Google， 找到了类似的问题[MYSQL On Kubernetes(IPVS)引发的TCP超时问题定位](https://berlinsaint.github.io/blog/2018/11/01/Mysql_On_Kubernetes%E5%BC%95%E5%8F%91%E7%9A%84TCP%E8%B6%85%E6%97%B6%E9%97%AE%E9%A2%98%E5%AE%9A%E4%BD%8D/)

但是通过设置节点的`net.ipv4.tcp_keepalive_time`参数, 并不能把问题解决, 而且进入容器查看, 发现相关参数并未被传递到pod内部

> maybe 文章是18年的, 可能后续因为安全原因把相关sysctl的参数禁止了??

然后继续Google, 基本上解决办法都是通过设置`net.ipv4.tcp_keepalive_time`, 不过因为节点的设置无法传递到pod内部, 
因此需要在pod内部去设置

在 `k8s 1.12`中, k8s可以通过设置`securityContext`来配置相关的sysctl参数

<!-- more -->

[官方文档](https://kubernetes.io/docs/tasks/administer-cluster/sysctl-cluster/)

但是默认情况下, 只是对外提供了几个相关的参数

很遗憾, 里面并不包含我们需要设置的`net.ipv4.tcp_keepalive_time`, 因此为了使用这个参数我们还需要配置`kubelet`

在`k8s 1.10`以后我们可以通过默认路径下的配置文件`/var/lib/kubelet/config.yaml`去配置相关kubelet的启动参数, 据说可以在运行时更新, 当然我没测

相关可以添加的参数可以查看[v1/types.go](https://github.com/kubernetes/kubernetes/blob/master/staging/src/k8s.io/kubelet/config/v1beta1/types.go#L774)

我们在文件下方添加:

```yaml
allowedUnsafeSysctls:
 - net.ipv4.*
```

因为节点比较多, 所以通过ansible来加了, 使用了`ansible-playbook`, 当然注意的是文件内默认没有`allowedUnsafeSysctls:`, 所以在最后添加了

```yaml
---

- name: kubelet config
  hosts: "docker"
  gather_facts: no
  tasks:
  - name: insert file value
    lineinfile:
      dest: /var/lib/kubelet/config.yaml
      line: "{{item}}"
    with_items:
    - "allowedUnsafeSysctls:"
    - "- net.ipv4.*"
```

然后我们修改部署的deploy内容在`spec.template.spec`下面添加:

```yaml
securityContext:
    sysctls:
    - name: net.ipv4.tcp_keepalive_time
      value: "800"
```

等待pod重启以后, 进去查看可以看到已经变成了

```shell
> sysctl net.ipv4.tcp_keepalive_time
# net.ipv4.tcp_keepalive_time = 800
```

// TODO 然后需要等待测试结果了