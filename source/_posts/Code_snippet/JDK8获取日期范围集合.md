---
title: JDK8获取日期范围集合.md
date: 2020-09-24 14:33:00
updated: 2020-09-24 14:33:00
tags:
 - jdk8
 - utils
categories:
 - - 代码
---

jdk8中引入的时间类的确好用，这里收藏一个关于创建一个两个日期之间的日期集合

<!-- more -->

直接上代码：

```java
/**
 * 提供一个创建日期范围集合的类, 可以使用forEach等方式来实现遍历两个日期之间的所有日期
 *
 * @author ren jie
 **/
public class DateRange implements Iterable<LocalDate> {

    private final LocalDate startDate;
    private final LocalDate endDate;

    private final TemporalUnit unit;

    /**
     * 默认通过Day来创建集合
     *
     * @param startDate 开始日期
     * @param endDate   结束日期
     */
    public DateRange(LocalDate startDate, LocalDate endDate) {
        this(startDate, endDate, ChronoUnit.DAYS);
    }

    public DateRange(LocalDate startDate, LocalDate endDate, TemporalUnit unit) {
        if (startDate.isAfter(endDate)) {
            throw new IllegalArgumentException("开始日期不能在结束日期之后");
        }
        this.startDate = startDate;
        this.endDate = endDate;
        this.unit = unit;

    }

    @Override
    public Iterator<LocalDate> iterator() {
        return stream().iterator();
    }

    /**
     * 获取一个stream流
     *
     * @return 返回 {@link Stream} 类
     */
    public Stream<LocalDate> stream() {
        return Stream.iterate(startDate, d -> d.plus(1, unit))
            .limit(unit.between(startDate, endDate) + 1);
    }

    /**
     * 通过 {@link #stream()} 方法来创建一个List集合, 提供的是ArrayList实现的list
     *
     * @return 返回list集合
     */
    public List<LocalDate> toList() {
        return stream().collect(Collectors.toList());
    }
}
```