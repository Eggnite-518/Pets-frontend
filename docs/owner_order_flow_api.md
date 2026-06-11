# 宠物主发单流程接口文档

> 适用流程：选宠物（从宠物档案选择或新建） -> 选择服务（遛 / 喂） -> 选择地址与时间（可用地址模板） -> 后端计算价格 -> 付款。
>
> 本文是目标接口契约，供前端、后端、Apifox 对齐。若后端现有 DTO 字段不足，按本文补齐。

---

## 1. 全局约定

### 1.1 鉴权

除登录/注册外，以下接口均需要登录态：

```http
Authorization: Bearer <token>
```

用户身份由 token 解析，前端不传 `ownerId`。

### 1.2 统一响应

```json
{
  "code": "0",
  "message": "success",
  "data": {},
  "requestId": "optional-trace-id"
}
```

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `code` | string | 业务码，`"0"` 表示成功 |
| `message` | string | 提示信息 |
| `data` | object / array / null | 业务数据 |
| `requestId` | string / null | 请求追踪 ID，可选 |

### 1.3 枚举

#### 宠物类型 `petType`

| 值 | 含义 |
| --- | --- |
| `1` | 猫 |
| `2` | 狗 |
| `3` | 异宠 |

#### 服务类型 `serviceType`

| 值 | 含义 | 说明 |
| --- | --- | --- |
| `1` | 喂 | 上门喂食 / 换水 / 基础照看 |
| `2` | 遛 | 上门遛宠，通常用于狗，也允许产品规则决定是否限制宠物类型 |

#### 订单状态 `orderStatus`

| 值 | 含义 |
| --- | --- |
| `1` | 悬赏中，等待宠托师报名 |
| `2` | 待支付，已选定宠托师 |
| `3` | 待履约，已支付 |
| `4` | 履约中 |
| `5` | 已完成 |
| `6` | 已取消，建议新增 |

---

## 2. 流程总览

1. 前端调用 `GET /api/v1/pet-archives` 获取我的宠物档案。
2. 如果用户没有合适宠物，跳转新建宠物页，调用 `POST /api/v1/pet-archives`。
3. 用户选择 `serviceType`：`1=喂`、`2=遛`。
4. 前端调用 `GET /api/v1/user-addresses` 获取地址模板，或新建地址模板。
5. 用户选择服务日期和时间段。
6. 前端调用 `POST /api/v1/orders/quote` 获取后端计算的价格明细。
7. 用户确认后调用 `POST /api/v1/orders` 创建订单，后端再次按同一套规则计算价格并落库，前端不能传最终金额。
8. 订单进入支付页，调用 `POST /api/v1/orders/{orderId}/payments` 发起付款。

---

## 3. 宠物档案接口

### API-1 获取我的宠物档案列表

```http
GET /api/v1/pet-archives
```

#### Query

| 字段 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| `petName` | string | 否 | 按宠物昵称模糊搜索 |
| `petType` | integer | 否 | 宠物类型：`1=猫`、`2=狗`、`3=异宠` |

#### 响应 `data`

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `petId` | string | 宠物档案 ID |
| `ownerId` | string | 宠物主用户 ID |
| `petName` | string | 宠物昵称 |
| `petType` | integer | 宠物类型 |
| `petTypeDesc` | string | 宠物类型文案 |
| `defaultReq` | string / null | 默认服务要求 |

```json
{
  "code": "0",
  "message": "success",
  "data": [
    {
      "petId": "3001",
      "ownerId": "1001",
      "petName": "团团",
      "petType": 1,
      "petTypeDesc": "猫",
      "defaultReq": "猫粮在厨房，换新水"
    }
  ]
}
```

### API-2 新建宠物档案

```http
POST /api/v1/pet-archives
```

#### Body

| 字段 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| `petName` | string | 是 | 宠物昵称，最长 50 字符 |
| `petType` | integer | 是 | `1=猫`、`2=狗`、`3=异宠` |
| `defaultReq` | string | 否 | 默认服务要求 |

```json
{
  "petName": "可乐",
  "petType": 2,
  "defaultReq": "胆子小，遛狗时请牵短绳"
}
```

#### 响应 `data`

同 API-1 的单个宠物档案对象。

---

## 4. 地址模板接口

> 前端当前已有 `/api/v1/user-addresses` 调用入口，后端需要补齐对应 Controller / Service。

### API-3 获取地址模板列表

```http
GET /api/v1/user-addresses
```

#### 响应 `data`

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `addressId` | string | 地址模板 ID |
| `contactName` | string | 联系人 |
| `contactPhone` | string | 联系电话 |
| `province` | string | 省 |
| `city` | string | 市 |
| `district` | string | 区/县 |
| `detailAddress` | string | 详细地址 |
| `addressTag` | string / null | 地址标签，如“家”“公司” |
| `isDefault` | integer | 是否默认地址，`0=否`、`1=是` |

```json
{
  "code": "0",
  "message": "success",
  "data": [
    {
      "addressId": "5001",
      "contactName": "王先生",
      "contactPhone": "13800000000",
      "province": "上海市",
      "city": "上海市",
      "district": "静安区",
      "detailAddress": "南京西路 1266 号 A 座 2805",
      "addressTag": "家",
      "isDefault": 1
    }
  ]
}
```

### API-4 新建地址模板

```http
POST /api/v1/user-addresses
```

#### Body

| 字段 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| `contactName` | string | 是 | 联系人 |
| `contactPhone` | string | 是 | 联系电话 |
| `province` | string | 是 | 省 |
| `city` | string | 是 | 市 |
| `district` | string | 是 | 区/县 |
| `detailAddress` | string | 是 | 详细地址 |
| `addressTag` | string | 否 | 地址标签 |
| `isDefault` | integer | 否 | `0=否`、`1=是`，默认 `0` |

#### 响应 `data`

同 API-3 的单个地址对象。

---

## 5. 价格计算接口

### API-5 订单价格预估

```http
POST /api/v1/orders/quote
```

> 用于确认页展示价格。后端根据宠物、服务类型、地址、时间自动计算，前端只传影响价格的业务参数，不传金额。

#### Body

| 字段 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| `petIds` | string[] | 是 | 已选择的宠物档案 ID，至少 1 个 |
| `serviceType` | integer | 是 | `1=喂`、`2=遛` |
| `addressId` | string | 是 | 地址模板 ID |
| `serviceDate` | string | 是 | 服务日期，格式 `YYYY-MM-DD` |
| `serviceStartTime` | string | 是 | 开始时间，格式 `HH:mm` |
| `serviceEndTime` | string | 是 | 结束时间，格式 `HH:mm` |
| `remark` | string | 否 | 本次服务备注 |

```json
{
  "petIds": ["3001", "3002"],
  "serviceType": 1,
  "addressId": "5001",
  "serviceDate": "2026-05-25",
  "serviceStartTime": "14:00",
  "serviceEndTime": "15:00",
  "remark": "请拍照反馈"
}
```

#### 响应 `data`

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `quoteId` | string / null | 报价 ID，可选；如果后端需要防篡改/过期校验可返回 |
| `currency` | string | 币种，默认 `CNY` |
| `totalAmount` | string | 应付总价，保留 2 位小数 |
| `priceItems` | array | 价格明细 |
| `expiresAt` | string / null | 报价过期时间，可选 |

#### `priceItems[]`

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `itemCode` | string | 明细编码，如 `BASE_SERVICE`、`PET_COUNT`、`TIME_SURCHARGE` |
| `itemName` | string | 展示名称 |
| `amount` | string | 金额，正数为加价，负数为优惠 |
| `quantity` | integer | 数量 |
| `remark` | string / null | 说明 |

```json
{
  "code": "0",
  "message": "success",
  "data": {
    "quoteId": "Q202605250001",
    "currency": "CNY",
    "totalAmount": "70.00",
    "priceItems": [
      {
        "itemCode": "BASE_SERVICE",
        "itemName": "上门喂养",
        "amount": "35.00",
        "quantity": 2,
        "remark": "35 元/只"
      }
    ],
    "expiresAt": "2026-05-24 18:30:00"
  }
}
```

---

## 6. 订单接口

### API-6 创建订单

```http
POST /api/v1/orders
```

> 创建订单时后端必须重新计算价格并保存价格快照，不能信任前端传入金额。

#### Body

| 字段 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| `petIds` | string[] | 是 | 已选择的宠物档案 ID |
| `serviceType` | integer | 是 | `1=喂`、`2=遛` |
| `addressId` | string | 是 | 地址模板 ID，后端创建订单地址快照 |
| `serviceDate` | string | 是 | 服务日期，格式 `YYYY-MM-DD` |
| `serviceStartTime` | string | 是 | 开始时间，格式 `HH:mm` |
| `serviceEndTime` | string | 是 | 结束时间，格式 `HH:mm` |
| `remark` | string | 否 | 本次服务备注，会进入订单宠物快照或订单备注 |
| `quoteId` | string | 否 | API-5 返回的报价 ID；如果后端不落报价可不传 |

```json
{
  "petIds": ["3001"],
  "serviceType": 2,
  "addressId": "5001",
  "serviceDate": "2026-05-25",
  "serviceStartTime": "19:00",
  "serviceEndTime": "19:30",
  "remark": "遛狗 30 分钟，出门请带牵引绳",
  "quoteId": "Q202605250001"
}
```

#### 响应 `data`

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `orderId` | string | 订单 ID |
| `totalAmount` | string | 后端计算后的订单总价 |
| `orderStatus` | integer | 创建后的订单状态，通常为 `1=悬赏中`；若产品改为立即付款，也可为 `2=待支付` |
| `serviceType` | integer | 服务类型 |
| `serviceDate` | string | 服务日期 |
| `serviceStartTime` | string | 开始时间 |
| `serviceEndTime` | string | 结束时间 |
| `createdAt` | string | 创建时间 |

```json
{
  "code": "0",
  "message": "success",
  "data": {
    "orderId": "9001",
    "totalAmount": "35.00",
    "orderStatus": 1,
    "serviceType": 2,
    "serviceDate": "2026-05-25",
    "serviceStartTime": "19:00",
    "serviceEndTime": "19:30",
    "createdAt": "2026-05-24 17:20:00"
  }
}
```

### API-7 查询订单确认信息

```http
GET /api/v1/orders/{orderId}
```

> 用于支付前确认页、订单详情页复用。当前后端如无该接口，建议新增。

#### 响应 `data`

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `orderId` | string | 订单 ID |
| `orderStatus` | integer | 订单状态 |
| `serviceType` | integer | 服务类型 |
| `serviceTypeText` | string | 服务类型文案 |
| `serviceDate` | string | 服务日期 |
| `serviceStartTime` | string | 开始时间 |
| `serviceEndTime` | string | 结束时间 |
| `totalAmount` | string | 订单总价 |
| `priceItems` | array | 价格快照明细 |
| `pets` | array | 宠物快照 |
| `addressSnapshot` | object | 地址快照 |
| `remark` | string / null | 备注 |

```json
{
  "code": "0",
  "message": "success",
  "data": {
    "orderId": "9001",
    "orderStatus": 2,
    "serviceType": 1,
    "serviceTypeText": "喂",
    "serviceDate": "2026-05-25",
    "serviceStartTime": "14:00",
    "serviceEndTime": "15:00",
    "totalAmount": "35.00",
    "priceItems": [
      { "itemCode": "BASE_SERVICE", "itemName": "上门喂养", "amount": "35.00", "quantity": 1, "remark": null }
    ],
    "pets": [
      { "petId": "3001", "petName": "团团", "petType": 1, "petTypeDesc": "猫", "serviceReq": "猫粮在厨房" }
    ],
    "addressSnapshot": {
      "contactName": "王先生",
      "contactPhone": "13800000000",
      "province": "上海市",
      "city": "上海市",
      "district": "静安区",
      "detailAddress": "南京西路 1266 号 A 座 2805",
      "addressTag": "家"
    },
    "remark": "请拍照反馈"
  }
}
```

---

## 7. 支付接口

### API-8 发起订单支付

```http
POST /api/v1/orders/{orderId}/payments
```

#### Body

| 字段 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| `payChannel` | string | 否 | 支付渠道：`BALANCE`、`WECHAT`、`ALIPAY`。如果当前是模拟支付，可不传 |

```json
{
  "payChannel": "BALANCE"
}
```

#### 响应 `data`

如果当前阶段仍是模拟支付，建议返回支付后的订单状态：

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `orderId` | string | 订单 ID |
| `paymentId` | string / null | 支付流水 ID，可选 |
| `orderStatus` | integer | 支付后状态，通常为 `3=待履约` |
| `paidAmount` | string | 实付金额 |
| `paidAt` | string | 支付完成时间 |

```json
{
  "code": "0",
  "message": "success",
  "data": {
    "orderId": "9001",
    "paymentId": "P202605240001",
    "orderStatus": 3,
    "paidAmount": "35.00",
    "paidAt": "2026-05-24 17:25:00"
  }
}
```

如果后续接第三方支付，`data` 可改为：

| 字段 | 类型 | 说明 |
| --- | --- | --- |
| `paymentId` | string | 支付流水 ID |
| `payChannel` | string | 支付渠道 |
| `payPayload` | object | 拉起微信/支付宝所需参数 |
| `expiresAt` | string | 支付单过期时间 |

---

## 8. 校验规则建议

| 场景 | 规则 |
| --- | --- |
| 选择宠物 | `petIds` 不能为空；所有宠物必须属于当前登录宠物主 |
| 新建宠物 | `petName` 必填且不超过 50 字符；`petType` 只能是 `1/2/3` |
| 服务类型 | `serviceType` 只能是 `1/2`；是否允许“猫选择遛 / 其他选择遛”由产品规则决定 |
| 地址 | `addressId` 必须属于当前登录宠物主；创建订单时保存地址快照 |
| 时间 | `serviceDate` 不能早于当天；`serviceStartTime < serviceEndTime` |
| 价格 | 价格只能由后端计算，创建订单时重新计算并保存快照 |
| 支付 | 只有待支付订单允许支付；支付金额以订单价格快照为准 |

---

## 9. 需要后端补齐的字段/表

当前后端已有 `orders.service_date`，但新流程需要服务时间段和服务类型，建议补齐：

| 表 | 字段 | 类型 | 说明 |
| --- | --- | --- | --- |
| `orders` | `service_type` | TINYINT | `1=喂`、`2=遛` |
| `orders` | `service_start_time` | TIME | 服务开始时间 |
| `orders` | `service_end_time` | TIME | 服务结束时间 |
| `orders` | `remark` | TEXT | 订单备注，可选 |
| `order_price_items` | `item_code` / `item_name` / `amount` / `quantity` | - | 价格明细快照，建议新增表 |

---

## 10. 待确认问题

1. 付款时机：现在后端逻辑是“发单 -> 宠托师报名 -> 宠物主选人 -> 待支付 -> 付款”；你这次描述像是“后端算价 -> 立即付款”。需要确认是否改成创建订单后直接待支付。
2. 价格规则：基础价、按宠物数量加价、遛/喂价格是否不同、夜间/节假日是否加价，需要产品给规则。
3. `其他` 类型宠物是否允许选择 `遛`，还是只允许 `喂`。
4. 支付阶段是模拟支付，还是需要微信/支付宝支付参数。
