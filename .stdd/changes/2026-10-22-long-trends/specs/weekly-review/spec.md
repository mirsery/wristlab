# Spec: weekly-review

> Change: 2026-10-22-long-trends | Auto-generated Human View

## Requirements

### Requirement: 近7日与此前28日对比

#### Scenario: SC-WEEK-001

- **GIVEN** 35日history，近7日有效日为3、2与4，此前28日有效日为10、9与12，含真实0与窗口外行，纽约夏令时周
- **WHEN** 生成周回顾
- **THEN** SHALL 达到门槛时输出两段均值、有效天数与差值（近7日−此前28日），未达门槛的一段均值为nil且不给差值
- **AND** 真实0计入均值，负荷不参与，窗口外行不计
- **AND** 差值文本按显示精度先取整再相减，零不带符号

#### Scenario: SC-WEEK-002

- **GIVEN** 首页近7日回顾卡片
- **WHEN** 查看
- **THEN** SHALL 显示四项的近7日与此前28日均值、有效天数和差值，记录不足明确写出，不含原因或建议
