# Exposing GemFire Statistics via JMX

GemFire currently exposes a wide range of metrics through Java Management Extensions (JMX). However, there are still hundreds of additional metrics that can be exposed. This project aims to extend the existing capabilities by exposing more GemFire metrics via JMX, enabling diverse methods for consuming this information.

## Table of Contents

- [Introduction](#introduction)
- [Understanding Statistics Definitions](#understanding-statistics-definitions)
- [Specifying Metrics for Display](#specifying-metrics-for-display)
- [Project Example and Output](#project-example-and-output)
- [Resources](#resources)

## Introduction

**GemFire** is a robust in-memory data grid that provides extensive metrics for monitoring and management. While many metrics are available through JMX, this project enhances GemFire's monitoring capabilities by exposing additional metrics via JMX. This allows for more comprehensive monitoring and integration with various tools and dashboards.

### GemFire VSD showing some of the categories of metrics GemFire offers
![GemFire Metrics Overview](/images/vsd.png)

## Understanding Statistics Definitions

To access all the metrics that GemFire exposes, you can use a specialized tool called VSD that displays the "gfs" metrics file. This tool helps you explore and understand the available metrics.

### Viewing Metrics Files

The tool's functionality is demonstrated in the image above. For detailed documentation on how to use this tool and view the metrics files, refer to the [VMware GemFire VSD Documentation](https://techdocs.broadcom.com/us/en/vmware-tanzu/data-solutions/tanzu-gemfire/10-1/gf/tools_modules-vsd-chapter_overview.html).

## Specifying Metrics for Display

To effectively expose specific metrics, you can define them using a customizable approach with regular expressions. This allows for bulk exposure of metrics based on patterns, making the configuration both flexible and scalable.

### Configuration via Properties File

Metrics are specified using a plain properties file with the following format:

```
<Metric Type>:[Optional Resource RegEx |]<Metric RegEx>[,<Subsequent Metric RegEx>]
```

#### Example Configuration

```properties
VMMemoryPoolStats: .*Survivor.*|current.*,foo
```

- **Metric Type**: `VMMemoryPoolStats`
- **Property Value**: Consists of the metric resource and metric regular expressions separated by a `|` character.

**Details:**

- If the `|` symbol is absent, the parser defaults the metric resource name to the regular expression `.*`.
- Metric regular expressions are specified as a comma-separated list.

**Explanation of the Example:**

- **Resource Regex**: `.*Survivor.*` — Exposes all resources containing the word "Survivor".
- **Metric Regexes**: `current*` and `foo` — Exposes metrics that start with "current" or exactly match "foo".

**Note:** Regular expressions must be carefully crafted to avoid parsing issues, especially with commas. Feel free to adjust the implementation to suit your application's requirements.

## Project Example and Output

Let's walk through an example to see how this works in practice.

### Example Scenario

In this example, we focus on two specific statistics from `StatSampler`:

1. **delayDuration**: Measures the period between recording stats. This value should be relatively stable with minor variations (jitter). Significant jitter may indicate infrastructure issues affecting CPU access and timer accuracy.
2. **sampleTime**: Represents the time GemFire takes to write the array of stats to disk.
    - **Typical Values**:
        - **Direct Attached NVMe Drives**: Often zero.
        - **Virtualized Storage**: Single-digit milliseconds.
    - **High Values**: Tens to hundreds of milliseconds may indicate storage layer issues.

### Configuration File (`expose_metrics.properties`)

```properties
VMStats: .*
VMMemoryPoolStats: .*Survivor.*|current.*
StatSampler: delayDuration,sampleTime
CacheServerStats: current.*,acceptsInProgress
```

### Visual Representation

The following image shows the VisualVM process monitoring the exposed metrics:

![VisualVM Process Monitoring](/images/visualvm.png)

## Resources

- [GemFire Metrics Documentation](https://techdocs.broadcom.com/us/en/vmware-tanzu/data-solutions/tanzu-gemfire/10-1/gf/tools_modules-vsd-chapter_overview.html)
- [VisualVM Tool](https://visualvm.github.io/)

---

Feel free to contribute to this project by submitting issues or pull requests. Your feedback and improvements are highly appreciated!
