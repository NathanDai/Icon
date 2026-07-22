# Clash 规则配置

本目录用于存放 Clash / Clash Meta (Mihomo) / Clash Verge / Stash 等客户端适用的 Rule-Provider 规则文件。

## 规则文件列表

- [`rules.yaml`](rules.yaml): Clash 自定义规则样例文件 (behavior: classical)
- [`igpandi.yaml`](igpandi.yaml): IGPANDI 及 P&I 俱乐部与 CDN 相关规则集 (behavior: classical)

## Clash 配置引用示例

在 Clash 配置文件的 `rule-providers` 与 `rules` 节点中添加：

```yaml
rule-providers:
  custom-rules:
    type: http
    behavior: classical
    url: "https://raw.githubusercontent.com/NathanDai/Icon/main/clash/rules.yaml"
    interval: 86400
    path: ./ruleset/custom-rules.yaml

rules:
  - RULE-SET,custom-rules,DIRECT # 替换为所需的策略组（如 Proxy, DIRECT 等）
```

## 在线直链格式

```text
https://raw.githubusercontent.com/NathanDai/Icon/main/clash/<rule_name>.yaml
```
