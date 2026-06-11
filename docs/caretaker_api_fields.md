# 宠托师端接口文档

> **唯一参考文档**：Apifox 录入、后端实现、Flutter 数据层均以本文档为准。如有调整请同步修改本文件。

---

## 全局约定

### 统一响应外壳

所有接口响应均包裹在以下外壳中：

| 属性 | 类型 | 说明 |
|------|------|------|
| `success` | boolean | **优先判断字段**：`true` 表示业务成功，`false` 表示业务失败 |
| `code` | string | 业务状态码，成功通常为 `"0"`；失败时用于前端分支提示 |
| `message` | string | 提示文案，失败时说明原因；可直接用于 Toast 或映射本地文案 |
| `data` | object / array / null | 各接口正文；无数据时为 `null` |
| `requestId` | string / null | 请求追踪 ID，当前多数接口为 `null` |

**前端判断优先级**：先读 `success` 字段；若后端未返回 `success`，则 fallback 到 `code == "0"` 判断。

以下各节「`data`」均指外壳里的 `data` 字段。

### 枚举：订单状态

| 值 | 含义 | 备注 |
|----|------|------|
| `1` | 悬赏中 | 宠主发单，等待宠托师报名 |
| `2` | 待支付 | 宠主已选定宠托师，等待付款（短暂状态，前端不单独展示） |
| `3` | 待履约 | 付款完成，等待服务时段到来 |
| `4` | 履约中 | 当前时间在服务时段内，正在服务 |
| `5` | 待宠主确认 | 宠托师完成 nodeType=6 后进入此状态，等待宠主确认 |
| `6` | 已完成 | 宠主确认后触发结算，资金打入服务者钱包 |

> ⚠️ **旧文档中 `5=已完成` 已作废**，现在 `5=待宠主确认`、`6=已完成`。所有判断 `orderStatus` 的代码需按新枚举检查。

### 枚举：服务类型

| 值 | 含义 |
|----|------|
| `1` | 上门喂猫 |
| `2` | 上门遛狗 |

> 无「上门洗护」，不使用值 `3`。

---

## API-1 获取接单大厅订单列表

```
GET /api/v1/orders/open
```

### Query 参数

| 属性 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `caretakerLat` | number | 否 | 宠托师当前位置纬度（WGS-84，由设备 GPS 获取）；不传时 `distanceKm` 返回 `0`，`maxDistanceKm` 筛选无效 |
| `caretakerLng` | number | 否 | 宠托师当前位置经度（WGS-84，由设备 GPS 获取）；与 `caretakerLat` 同时传或同时不传 |
| `serviceType` | integer | 否 | 服务类型筛选：`1` 上门喂猫，`2` 上门遛狗；不传表示全部。筛选语义为「订单 `serviceItems` 中**包含**该类型即命中」 |
| `maxDistanceKm` | number | 否 | 距离上限（千米），如 `5`；不传或 `0` 表示不限；**需同时传 `caretakerLat`/`caretakerLng` 才生效** |
| `minAmount` | integer | 否 | 订单金额下限（含）；不传表示不限 |
| `maxAmount` | integer | 否 | 订单金额上限（含）；不传表示不限 |
| `serviceDate` | string | 否 | 服务日期筛选，格式 `YYYY-MM-DD`；不传表示全部日期 |
| `page` | integer | 否 | 当前页码，从 `1` 开始，默认 `1` |
| `pageSize` | integer | 否 | 每页条数，默认 `10` |

> HTTP Query 为字符串；`integer`/`number` 类型后端按对应数值解析。
>
> **坐标系说明**：`caretakerLat`/`caretakerLng` 为设备 GPS 原始坐标（WGS-84）；响应中订单的 `latitude`/`longitude` 为高德 GCJ-02。后端计算 `distanceKm` 时需自行做坐标系转换（偏差约 100–500m，不影响距离展示精度）。

### 响应 `data`

| 属性 | 类型 | 说明 |
|------|------|------|
| `total` | integer | 符合条件的订单总数（跨页） |
| `page` | integer | 当前返回的页码 |
| `pageSize` | integer | 当前页大小 |
| `list` | array | 本页订单列表，元素结构见下表 |

#### `list[]` 订单项

| 属性 | 类型 | 说明 |
|------|------|------|
| `orderId` | string | 订单唯一标识 |
| `serviceItems` | array | **一单对应的所有服务类型**（至少一项），元素见下表 |
| `totalAmount` | integer | 订单金额（单位与全站一致） |
| `serviceDate` | string | 服务日期，`YYYY-MM-DD` |
| `serviceTimeSlot` | string | 服务时段，如 `14:00` 或 `14:30 - 15:00` |
| `addressDistrict` | string | 服务地址区县摘要，用于「静安区 · 距 x km」展示 |
| `latitude` | number\|null | 服务地址纬度（高德坐标系 GCJ-02）；暂无时返回 `null` |
| `longitude` | number\|null | 服务地址经度（高德坐标系 GCJ-02）；暂无时返回 `null` |
| `distanceKm` | number | 相对宠托师定位的距离（千米）；无定位时返回 `0` |
| `applicationCount` | integer | 该订单已报名人数 |
| `isHot` | boolean | 是否展示「热门」角标 |
| `pets` | array | 关联宠物摘要列表，元素见下表 |
| `createdAt` | string | 订单创建时间，`YYYY-MM-DD HH:mm:ss` |

#### `serviceItems[]` 服务项

| 属性 | 类型 | 说明 |
|------|------|------|
| `serviceType` | integer | 服务类型枚举，见全局约定 |
| `serviceTypeText` | string | 展示文案（如「上门喂猫」），后端生成 |

#### `pets[]` 宠物摘要

| 属性 | 类型 | 说明 |
|------|------|------|
| `petName` | string | 宠物昵称 |
| `petType` | integer | 宠物类型枚举，与 `pet_archives.pet_type` 对齐 |

**响应示例**

```json
{
  "code": 0,
  "message": "ok",
  "data": {
    "total": 12, "page": 1, "pageSize": 10,
    "list": [{
      "orderId": "10086",
      "serviceItems": [
        { "serviceType": 1, "serviceTypeText": "上门喂猫" },
        { "serviceType": 2, "serviceTypeText": "上门遛狗" }
      ],
      "totalAmount": 120,
      "serviceDate": "2026-05-20",
      "serviceTimeSlot": "14:00",
      "addressDistrict": "静安区",
      "latitude": 31.2304,
      "longitude": 121.4737,
      "distanceKm": 1.2,
      "applicationCount": 3,
      "isHot": true,
      "pets": [{ "petName": "咪咪", "petType": 1 }],
      "createdAt": "2026-05-01 10:00:00"
    }]
  }
}
```

**Dart 对应**：`OrderHallPage` / `OrderHallItem` / `OrderHallPetInfo`（`order_hall_item_model.dart`）

---

## API-2 宠托师报名订单

```
POST /api/v1/orders/{orderId}/reservations
```

### Path 参数

| 属性 | 类型 | 说明 |
|------|------|------|
| `orderId` | string | 要报名的订单 ID |

### 请求 Body

请求体为 `{}`（宠托师身份从 Token 解析，无需额外参数）。

### 响应 `data`

| 属性 | 类型 | 说明 |
|------|------|------|
| `applicationId` | string | 本次报名记录 ID |

**响应示例**

```json
{ "code": 0, "message": "ok", "data": { "applicationId": "20001" } }
```

**Dart 对应**：`OrderHallRemoteDataSource.applyOrder`（`order_hall_remote_data_source.dart`）

---

## API-3 取消报名

```
DELETE /api/v1/orders/{orderId}/reservations
```

### Path 参数

| 属性 | 类型 | 说明 |
|------|------|------|
| `orderId` | string | 要取消报名的订单 ID |

### 请求 Body

无。

### 返回响应

后端返回统一响应体（**不是**空 Body）：

```json
{ "code": "0", "message": "success", "data": null, "success": true }
```

| HTTP | 含义 |
|------|------|
| `200` | 取消成功，`success=true` |
| `400` | 不允许取消（如已入选、订单已关闭） |
| `403` | 无权限（非本人报名） |
| `404` | 无对应报名记录或订单不存在 |

> **前端判断**：统一按 `success=true` 判断，不依赖空 Body。

**Dart 对应**：`OrderHallRemoteDataSource.cancelApplication`（`order_hall_remote_data_source.dart`）

---

## API-4 我的报名列表

```
GET /api/v1/caretaker/me/applications
```

> **过滤规则**：只返回该宠托师有报名记录且**订单状态 = `1`（悬赏中）** 的申请。不存在独立「报名状态」字段，统一使用全站订单状态枚举。

### 响应 `data`

**JSON 数组**（`data` 直接为数组，非分页对象）。

| 属性 | 类型 | 说明 |
|------|------|------|
| `applicationId` | string | 报名记录 ID |
| `orderId` | string | 关联订单 ID |
| `orderStatus` | integer | 订单状态，本接口只返回 `1`（悬赏中） |
| `orderStatusText` | string | 状态展示文案（如「等待反馈」），后端生成 |
| `serviceType` | integer | 服务类型枚举，见全局约定 |
| `serviceTypeText` | string | 服务类型展示文案 |
| `totalAmount` | integer | 订单金额 |
| `distanceKm` | number | 相对宠托师的距离（千米） |
| `petName` | string | 卡片主展示宠物名（多宠时由后端拼接） |
| `petAvatarUrl` | string | 宠物头像 URL；无图时返回 `""` |

**响应示例**

```json
{
  "code": 0, "message": "ok",
  "data": [{
    "applicationId": "20001",
    "orderId": "10086",
    "orderStatus": 1,
    "orderStatusText": "等待反馈",
    "serviceType": 2,
    "serviceTypeText": "上门遛狗",
    "totalAmount": 50,
    "distanceKm": 2.5,
    "petName": "大黄",
    "petAvatarUrl": "https://..."
  }]
}
```

**Dart 对应**：`MyApplication`（`my_application_model.dart`）

---

## API-5 待履约 + 履约中订单列表

```
GET /api/v1/caretaker/me/orders/active
```

> **过滤规则**：返回宠托师已入选且订单状态为 `3`（待履约）或 `4`（履约中）的订单，合并展示在首页「正在履约中」区块。前端根据 `orderStatus` 显示不同标签：`3` → 「待上门」，`4` → 「履约中」。

### 响应 `data`

**JSON 数组**。

| 属性 | 类型 | 说明 |
|------|------|------|
| `orderId` | string | 订单 ID，与履约打卡路由中的 id 一致 |
| `orderStatus` | integer | `3` 待履约，`4` 履约中 |
| `orderStatusText` | string | 状态展示文案：`3` → 「待上门」，`4` → 「履约中」，后端生成 |
| `serviceTypeText` | string | 服务类型展示，如「上门喂猫」 |
| `serviceDate` | string | 服务日期 |
| `serviceTimeSlot` | string | 服务时段字符串 |
| `addressSnapshot` | string | 服务地址快照摘要（脱敏规则由产品与后端约定） |
| `petName` | string | 宠物名称 |
| `petAvatarUrl` | string | 宠物头像 URL；无图可为 `""` |

**响应示例**

```json
{
  "code": 0, "message": "ok",
  "data": [{
    "orderId": "10086",
    "orderStatus": 4,
    "orderStatusText": "履约中",
    "serviceTypeText": "上门喂猫",
    "serviceDate": "2026-05-20",
    "serviceTimeSlot": "14:30 - 15:00",
    "addressSnapshot": "海淀区 交大东路 1202",
    "petName": "咪咪",
    "petAvatarUrl": "https://..."
  }]
}
```

**Dart 对应**：`ActiveOrder`（`active_order_model.dart`）

---

## API-6 工作台统计数据

```
GET /api/v1/caretaker/me/stats
```

### 响应 `data`

| 属性 | 类型 | 说明 |
|------|------|------|
| `todayOrderCount` | integer | 今日待服务单量 |
| `creditScore` | integer | 宠托师信用分 |
| `pendingPaymentCount` | integer | 待支付订单数（宠主已选中但未付款）；为 `0` 时前端不展示提示条 |

**响应示例**

```json
{ "code": 0, "message": "ok", "data": { "todayOrderCount": 4, "creditScore": 98, "pendingPaymentCount": 1 } }
```

**Dart 对应**：`CaretakerStats`（`caretaker_stats_model.dart`）

---

## API-7 获取当前接单状态

```
GET /api/v1/caretaker/me/availability
```

### 响应 `data`

| 属性 | 类型 | 说明 |
|------|------|------|
| `isAvailable` | boolean | `true` 接单中，`false` 休息中 |

**响应示例**

```json
{ "code": 0, "message": "ok", "data": { "isAvailable": true } }
```

---

## API-8 更新接单状态

```
PUT /api/v1/caretaker/me/availability
```

### 请求 Body

| 属性 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `isAvailable` | boolean | 是 | `true` 开启接单，`false` 关闭接单 |

### 响应 `data`

`null`（成功即可，HTTP `200` + 外层 `code` 成功表示更新完成）。

---

## API-9 添加履约打卡记录

```
POST /api/v1/caretaker/orders/{orderId}/fulfillment
```

> 共 **6 个打卡节点**，按顺序逐一解锁。  
> - `nodeType=2`（入户确认）：**必须**上传图片文件（`multipart/form-data`）  
> - `nodeType=6`（锁门离场）：**必须**上传视频文件（`multipart/form-data`），后端异步处理，完成后自动推进订单为 `5=待宠主确认`（需宠主确认后才进入 `6=已完成`）  
> - 其余节点：`application/json` 即可，无需文件

### Path 参数

| 属性 | 类型 | 说明 |
|------|------|------|
| `orderId` | string | 正在履约的订单 ID |

### 请求字段

**无文件节点（nodeType ≠ 2 且 ≠ 6）**：`Content-Type: application/json`

| 属性 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `nodeType` | integer | 是 | 打卡节点编号 |
| `lat` | number | 否 | 打卡纬度（WGS-84）；传入后后端做距离校验 |
| `lng` | number | 否 | 打卡经度，需与 `lat` 同时传或同时不传 |

**有文件节点（nodeType=2 图片 / nodeType=6 视频）**：`Content-Type: multipart/form-data`

| 字段名 | 类型 | 必填 | 说明 |
|--------|------|------|------|
| `nodeType` | integer | 是 | `2` 或 `6` |
| `file` | file | 是 | `nodeType=2` 传图片；`nodeType=6` 传视频（如 `.mp4`） |
| `lat` | number | 否 | 打卡纬度 |
| `lng` | number | 否 | 打卡经度 |

**请求示例（节点 1，JSON）**

```json
{ "nodeType": 1 }
```

**请求示例（节点 2，multipart 图片）**

```
POST /api/v1/caretaker/orders/{orderId}/fulfillment
Content-Type: multipart/form-data

nodeType=2
file=<binary image data>
```

**请求示例（节点 6，multipart 视频）**

```
POST /api/v1/caretaker/orders/{orderId}/fulfillment
Content-Type: multipart/form-data

nodeType=6
file=<binary video data>
```

### 响应 `data`

| 属性 | 类型 | 说明 |
|------|------|------|
| `recordId` | integer/string | 履约记录 ID |
| `orderId` | integer/string | 订单 ID |
| `nodeType` | integer | 本次提交的履约节点 |
| `mediaType` | string/null | 媒体类型：`IMAGE`、`VIDEO` 或 `null` |
| `objectKey` | string/null | OSS 对象唯一标识（私有读 Bucket），前端只展示不持久化 |
| `mediaUrl` | string/null | 可访问媒体 URL（私有 Bucket 下为带签名临时 URL，会过期） |
| `fileSize` | integer/null | 文件大小，单位字节 |
| `contentType` | string/null | 文件 MIME 类型，如 `video/mp4`、`image/jpeg` |
| `frameRate` | integer/null | 视频帧率，仅视频处理成功后可能有值 |
| `processingStatus` | string | 处理状态：`PROCESSING`=处理中，`SUCCESS`=成功，`FAILED`=失败 |

**响应示例（图片节点，立即成功）**

```json
{
  "code": "0", "message": "success", "success": true,
  "data": {
    "recordId": 10001,
    "orderId": "10086",
    "nodeType": 2,
    "mediaType": "IMAGE",
    "objectKey": "fulfillment/10086/node2/abc.jpg",
    "mediaUrl": "https://oss.example.com/abc.jpg?sign=xxx",
    "fileSize": 204800,
    "contentType": "image/jpeg",
    "frameRate": null,
    "processingStatus": "SUCCESS"
  }
}
```

**响应示例（视频节点，异步处理中）**

```json
{
  "code": "0", "message": "success", "success": true,
  "data": {
    "recordId": 10002,
    "orderId": "10086",
    "nodeType": 6,
    "mediaType": "VIDEO",
    "objectKey": "fulfillment/10086/node6/abc.mp4",
    "mediaUrl": null,
    "fileSize": null,
    "contentType": "video/mp4",
    "frameRate": null,
    "processingStatus": "PROCESSING"
  }
}
```

**前端处理建议**

| 场景 | 处理方式 |
|------|---------|
| 普通节点上传成功 | 根据 `success=true` 标记节点完成 |
| 视频节点返回 `PROCESSING` | 展示「视频处理中」，可轮询 API-12 |
| 视频节点返回 `SUCCESS` | 使用 `mediaUrl` 播放视频 |
| 视频节点返回 `FAILED` | 展示失败提示，允许重新上传 |
| `nodeType=6` 上传后 | 后端自动推进为 `5=待宠主确认`，前端展示「等待宠主确认完成」并返回上页 |

> ⚠️ `mediaUrl` 为带签名的临时 URL，**不要缓存**，需要展示时重新拉取 API-12。

**Dart 对应**：`AddFulfillmentRecordUseCase` / `FulfillmentRemoteDataSource.addFulfillmentRecord`

---

## API-10 上传图片（已废弃，不再使用）

```
POST /api/v1/upload/image
```

> ~~通用图片上传接口，当前用于履约打卡的入户照片。前端先调此接口拿到 URL，再将 URL 传给 API-9。~~

> **⚠️ 废弃说明**：API-9 履约打卡接口已支持直接在请求中以 `multipart/form-data` 传入 `file` 字段，后端统一处理 OSS 存储、水印和临时 URL 生成，**前端不再需要单独调用此上传接口**。  
> 保留文档仅供参考，前端代码中不调用此接口。

---

## API-11 完成服务（已废弃，不再调用）

```
POST /api/v1/caretaker/orders/{orderId}/complete
```

> **⚠️ 废弃说明**：后端在 `nodeType=6`（锁门离场）打卡成功后**自动**将订单状态推进为 `5=待宠主确认`，不需要前端额外调用此接口。宠主确认后才进入 `6=已完成`。  
> 前端 UI 已移除「完成服务」按钮，`nodeType=6` 上传成功后直接返回上页。  
> 保留文档仅供参考，`FulfillmentRepository.completeOrder` / `CompleteOrderUseCase` 在数据层保留但 UI 层不再调用。

---

## API-12 查询履约打卡记录

```
GET /api/v1/caretaker/orders/{orderId}/fulfillment-records
```

> 宠托师进入履约打卡页时调用，恢复已完成的节点状态，避免中途退出后重置。

### Path 参数

| 属性 | 类型 | 说明 |
|------|------|------|
| `orderId` | string | 订单 ID |

### 请求 Body

无。

### 响应 `data`

| 属性 | 类型 | 说明 |
|------|------|------|
| `records` | array | 已完成的打卡记录列表，未打卡节点不出现；元素见下表 |

#### `records[]` 打卡记录项

| 属性 | 类型 | 说明 |
|------|------|------|
| `nodeType` | integer | 节点类型：`1`=抵达签到，`2`=入户确认，`3`=喂食换水，`4`=铲屎清洁，`5`=遛宠中，`6`=锁门离场 |
| `imageUrl` | string/null | 兼容字段：图片节点是图片 URL；视频节点处理成功后是视频临时 URL；无媒体时为 `null` |
| `mediaType` | string/null | 媒体类型：`IMAGE`、`VIDEO` 或 `null` |
| `objectKey` | string/null | OSS 对象 Key，后端用于生成临时 URL，前端只展示 |
| `fileSize` | integer/null | 处理后媒体大小，单位字节 |
| `contentType` | string/null | 处理后媒体 MIME 类型，如 `video/mp4`、`image/jpeg` |
| `frameRate` | integer/null | 视频帧率，仅视频处理成功后有值 |
| `processingStatus` | string/null | 处理状态：`PROCESSING`=处理中，`SUCCESS`=成功，`FAILED`=失败；无媒体节点为 `null` |
| `processingErrorCode` | string/null | 处理失败错误码，便于前端做稳定分支 |
| `processingError` | string/null | 处理失败原因说明 |
| `watermarkText` | string/null | 后端实际写入视频的水印文案 |
| `createdAt` | string | 打卡时间，`YYYY-MM-DD HH:mm:ss` |

**前端展示建议**

| `processingStatus` | 展示 |
|--------------------|------|
| `null` | 普通无媒体节点，按节点完成状态展示 |
| `PROCESSING` | 节点已提交，媒体处理中，转圈提示 |
| `SUCCESS` | 使用 `imageUrl` 作为图片/视频地址 |
| `FAILED` | 展示处理失败，可允许重新上传 |

> ⚠️ `imageUrl` 为带签名的临时 URL，**不要缓存**，展示时重新拉取此接口获取最新 URL。

**响应示例**

```json
{
  "code": "0", "message": "success", "success": true,
  "data": {
    "records": [
      {
        "nodeType": 1, "imageUrl": null, "mediaType": null,
        "processingStatus": null, "createdAt": "2026-05-20 14:02:11"
      },
      {
        "nodeType": 2, "imageUrl": "https://oss.example.com/abc.jpg?sign=xxx",
        "mediaType": "IMAGE", "objectKey": "fulfillment/10086/node2/abc.jpg",
        "fileSize": 204800, "contentType": "image/jpeg",
        "processingStatus": "SUCCESS", "createdAt": "2026-05-20 14:05:33"
      },
      {
        "nodeType": 6, "imageUrl": null, "mediaType": "VIDEO",
        "objectKey": "fulfillment/10086/node6/abc.mp4",
        "processingStatus": "PROCESSING", "createdAt": "2026-05-20 14:30:00"
      }
    ]
  }
}
```

> 若订单尚无任何打卡记录，返回 `"records": []`。

**Dart 对应**：`FulfillmentRecord` entity / `FulfillmentRecordModel` / `FulfillmentRemoteDataSource.getFulfillmentRecords` / `GetFulfillmentRecordsUseCase`

---

## API-13 会话列表（订单关联私聊）

```
GET /api/v1/caretaker/me/conversations
```

> **过滤规则**：仅返回与当前宠托师相关的**订单私聊**会话（一订单一会话）；不含系统通知、财务消息等。  
> **Apifox 状态**：草案，待后端录入。

### 响应 `data`

**JSON 数组**。

| 属性 | 类型 | 说明 |
|------|------|------|
| `conversationId` | string | 会话 ID，进入聊天页时使用 |
| `orderId` | string | 关联订单 ID |
| `peerName` | string | 对方（宠主）展示昵称 |
| `peerAvatarUrl` | string | 对方头像 URL；无图时返回 `""` |
| `petName` | string | 订单宠物名，用于列表副标题；无则 `""` |
| `lastMessagePreview` | string | 最后一条消息摘要 |
| `lastMessageTimeText` | string | 列表右侧时间展示文案（如「刚刚」「10:30」「昨天」），后端格式化 |
| `unreadCount` | integer | 未读消息数；为 `0` 时不展示角标 |

**响应示例**

```json
{
  "code": 0,
  "message": "ok",
  "data": [{
    "conversationId": "3001",
    "orderId": "10086",
    "peerName": "林深见鹿",
    "peerAvatarUrl": "https://cdn.example.com/avatar/a.jpg",
    "petName": "大黄",
    "lastMessagePreview": "大黄比较怕生，麻烦刚开始接触的时候动作慢一点哦~",
    "lastMessageTimeText": "10:30",
    "unreadCount": 2
  }]
}
```

**Dart 对应**：`Conversation`（`conversation_model.dart`）/ `ConversationRemoteDataSource.getConversations`

---

## API-14 聊天记录

```
GET /api/v1/caretaker/conversations/{conversationId}/messages
```

> 宠托师场景下单次对话量有限，一次性返回全部消息，无需分页。消息按 `sentAt` **正序**（旧→新）排列，前端直接渲染到 `ListView` 并滚动至底部。

### Path 参数

| 属性 | 类型 | 说明 |
|------|------|------|
| `conversationId` | string | 会话 ID |

### 响应 `data`

直接返回消息数组（`array`），每个元素字段如下：

| 属性 | 类型 | 说明 |
|------|------|------|
| `messageId` | string | 消息 ID |
| `senderRole` | integer | 发送方：`1` 宠主，`2` 宠托师 |
| `content` | string | 文本内容 |
| `sentAt` | string | 发送时间，`YYYY-MM-DD HH:mm:ss` |

**响应示例**

```json
{
  "code": 0,
  "message": "ok",
  "data": [
    {
      "messageId": "4001",
      "senderRole": 1,
      "content": "钥匙已经放在门口地毯下面了，辛苦啦！",
      "sentAt": "2026-05-20 09:15:00"
    },
    {
      "messageId": "4002",
      "senderRole": 2,
      "content": "好的，我大概 10 点到",
      "sentAt": "2026-05-20 09:18:30"
    }
  ]
}
```

**Dart 对应**：`ChatMessage`（`chat_message_model.dart`）/ `GetChatMessagesUseCase`

---

## API-15 发送消息

```
POST /api/v1/caretaker/conversations/{conversationId}/messages
```

### Path 参数

| 属性 | 类型 | 说明 |
|------|------|------|
| `conversationId` | string | 会话 ID |

### 请求 Body

| 属性 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `content` | string | 是 | 文本消息内容 |

### 响应 `data`

返回刚发送的消息对象（字段与 API-14 数组元素相同）。

**响应示例**

```json
{
  "code": 0,
  "message": "ok",
  "data": {
    "messageId": "4003",
    "senderRole": 2,
    "content": "好的，我大概 10 点到",
    "sentAt": "2026-05-20 09:18:30"
  }
}
```

**Dart 对应**：`SendChatMessageUseCase`

---

## API-16 获取宠托师档案

```
GET /api/v1/me/caretaker
```

> 系统统计生成的字段（`certTags`、`rating`、`reviewCount`、`levelTag`）由后端自动维护，前端只读展示，**不允许前端手动修改**。

### 响应 `data`

#### 个人基础信息

| 属性 | 类型 | 说明 |
|------|------|------|
| `nickname` | string | 昵称 |
| `avatarUrl` | string | 头像 URL；无图时返回 `""` |
| `gender` | integer/null | 性别：`1`=男，`2`=女；后端未设置时为 `null` |
| `residentAddress` | string/null | 常驻地址；未设置时为 `null` |

#### 服务方需求

| 属性 | 类型 | 说明 |
|------|------|------|
| `serviceRangeKm` | integer | 最大服务半径（千米）；默认 `5` |

#### 养宠能力与经历

| 属性 | 类型 | 说明 |
|------|------|------|
| `certTags` | array\<string\> | 专业证书认证标签，如 `["实名认证"]`；**系统生成，只读** |
| `certLabels` | array\<string\> | 养宠经验/特色标签，如 `["5+年","持证美容师","平台认证"]`，最多 3 个 |
| `rating` | number | 综合评分（0.0–5.0）；**系统生成，只读**；`0` 时不展示 |
| `reviewCount` | integer | 评价总条数；**系统生成，只读** |
| `levelTag` | string | 等级标签，如「金牌宠托师」；**系统生成，只读**；无则 `""` |

> `workLocation`（工作常驻点）为隐私字段，仅系统内部使用，**不在此接口返回**。

**响应示例**

```json
{
  "code": "0", "message": "success", "success": true,
  "data": {
    "nickname": "林小木",
    "avatarUrl": "https://cdn.example.com/avatar/b.jpg",
    "gender": 1,
    "residentAddress": "静安区常德路街道",
    "serviceRangeKm": 5,
    "certTags": ["实名认证"],
    "certLabels": ["5+年", "持证美容师", "平台认证"],
    "rating": 4.9,
    "reviewCount": 128,
    "levelTag": "金牌宠托师"
  }
}
```

**Dart 对应**：`CaretakerProfile` / `CaretakerProfileModel`（`caretaker_profile_model.dart`）/ `GetCaretakerProfileUseCase`

---

## API-17 更新宠托师档案

```
PUT /api/v1/me/caretaker
```

> 以下字段为**必传**，后端整体更新；客户端须传入当前值，否则对应字段将被清空。

### 请求 Body

| 属性 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `nickname` | string | 是 | 昵称，不超过 20 字 |
| `avatarUrl` | string | 是 | 头像图片 URL（先通过上传接口获取 URL 再传入） |
| `certLabels` | array\<string\> | 是 | 特色标签，如 `["5+年","持证美容师"]`，最多 3 项；无时传 `[]` |
| `serviceRangeKm` | integer | 是 | 服务范围（千米）；默认 `5` |
| `residentAddress` | string | 否 | 常驻地址文字；不传时保持不变 |
| `residentLatitude` | number | 否 | 常驻地址纬度（WGS-84）；须与 `residentLongitude` 同时传或同时不传 |
| `residentLongitude` | number | 否 | 常驻地址经度（WGS-84） |

**请求示例**

```json
{
  "nickname": "林小木",
  "avatarUrl": "https://cdn.example.com/avatar/b.jpg",
  "certLabels": ["5+年", "持证美容师", "平台认证"],
  "serviceRangeKm": 5,
  "residentAddress": "静安区常德路街道",
  "residentLatitude": 31.2304,
  "residentLongitude": 121.4737
}
```

### 响应 `data`

`null`（`success=true` 即可）。

**Dart 对应**：`CaretakerProfileRemoteDataSource.updateProfile` / `UpdateServiceRangeUseCase`（`update_service_range_use_case.dart`）

---

## API-18 获取钱包余额

```
GET /api/v1/caretaker/me/wallet
```

### 响应 `data`

| 属性 | 类型 | 说明 |
|------|------|------|
| `balance` | string | 可提现余额，保留两位小数，如 `"2480.50"` |

**响应示例**

```json
{ "code": 0, "message": "ok", "data": { "balance": "2480.50" } }
```

**Dart 对应**：`CaretakerWallet`（`caretaker_wallet_model.dart`）/ `GetCaretakerWalletUseCase`

---

## API-19 申请提现

```
POST /api/v1/caretaker/me/wallet/withdraw
```

> 最低提现金额：¥10（整数元）；即时到账；提现金额不得超过当前余额整数部分。

### 请求 Body

| 属性 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `amount` | integer | 是 | 提现金额（整数元，≥ 10，≤ `floor(balance)`） |

**请求示例**

```json
{ "amount": 200 }
```

### 响应 `data`

| 属性 | 类型 | 说明 |
|------|------|------|
| `balance` | string | 提现后的最新可提现余额，保留两位小数 |

**响应示例**

```json
{ "code": 0, "message": "ok", "data": { "balance": "2280.50" } }
```

**Dart 对应**：`WithdrawUseCase` / `CaretakerWithdrawScreen`（提现页面 push 后返回新余额更新卡片）

---

## API-20 获取钱包流水记录

```
GET /api/v1/caretaker/me/wallet/records?page=1&pageSize=20
```

### 查询参数

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `page` | integer | 否 | 页码，默认 1 |
| `pageSize` | integer | 否 | 每页条数，默认 20 |

### 响应 `data`

| 属性 | 类型 | 说明 |
|------|------|------|
| `total` | integer | 总记录数 |
| `page` | integer | 当前页码 |
| `pageSize` | integer | 每页条数 |
| `list` | array | 流水记录列表，见下表 |

**`list[i]` 字段**

| 属性 | 类型 | 说明 |
|------|------|------|
| `recordId` | string | 记录唯一 ID |
| `type` | integer | 记录类型：`1`=订单收益，`2`=提现 |
| `typeText` | string | 类型展示文案，如 `"订单收益"`、`"提现"` |
| `direction` | integer | 资金方向：`1`=收入(+)，`2`=支出(-) |
| `amount` | string | 金额（始终为正数，保留两位小数），如 `"65.00"` |
| `description` | string | 摘要说明，如 `"订单 #10086 完成"` |
| `createdAt` | string | 创建时间，格式 `YYYY-MM-DD HH:mm:ss` |

**响应示例**

```json
{
  "code": 0, "message": "ok",
  "data": {
    "total": 2,
    "page": 1,
    "pageSize": 20,
    "list": [
      {
        "recordId": "5001",
        "type": 1,
        "typeText": "订单收益",
        "direction": 1,
        "amount": "65.00",
        "description": "订单 #10086 完成",
        "createdAt": "2026-05-20 14:30:00"
      },
      {
        "recordId": "5000",
        "type": 2,
        "typeText": "提现",
        "direction": 2,
        "amount": "200.00",
        "description": "提现至微信支付",
        "createdAt": "2026-05-18 09:12:00"
      }
    ]
  }
}
```

**Dart 对应**：`CaretakerIncomeRecord` / `CaretakerIncomeRecordPage`（`caretaker_income_record_model.dart`）/ `GetIncomeRecordsUseCase` / `CaretakerIncomeScreen`

---

## API-21 获取履约订单详情

```
GET /api/v1/caretaker/orders/{orderId}
```

> 宠托师点击履约订单卡片后进入详情页时调用。返回完整订单信息，包括宠主联系方式、宠物档案、服务地址及打卡进度。

### Path 参数

| 属性 | 类型 | 说明 |
|------|------|------|
| `orderId` | string | 订单 ID |

### 响应 `data`

| 属性 | 类型 | 说明 |
|------|------|------|
| `orderId` | string | 订单 ID |
| `orderStatus` | integer | 3=待履约，4=履约中，5=待宠主确认，6=已完成 |
| `orderStatusText` | string | 状态展示文案 |
| `serviceItems` | array | 服务项目列表，元素含 `serviceType`、`serviceTypeText` |
| `serviceDate` | string | 服务日期，`YYYY-MM-DD` |
| `serviceTimeSlot` | string | 服务时段，如 `14:00 - 15:00` |
| `totalAmount` | string | 订单金额，保留两位小数，如 `"120.00"` |
| `address` | object | 服务地址，见下表 |
| `owner` | object | 宠主信息，见下表 |
| `pets` | array | 宠物档案列表，见下表 |
| `serviceNotes` | string | 宠主的特殊说明（可为空）|
| `completedNodeTypes` | array\<integer\> | 已完成的打卡节点 nodeType 列表 |
| `createdAt` | string | 下单时间 |

#### `address` 字段

| 属性 | 类型 | 说明 |
|------|------|------|
| `fullAddress` | string | 完整地址（含楼栋门牌），用于导航 |
| `district` | string | 区县摘要，用于展示 |
| `lat` | number\|null | 纬度（WGS-84）|
| `lng` | number\|null | 经度（WGS-84）|

#### `owner` 字段

| 属性 | 类型 | 说明 |
|------|------|------|
| `nickname` | string | 宠主昵称 |
| `avatarUrl` | string | 头像 URL |
| `phone` | string | 脱敏手机号，如 `"138****8888"` |

#### `pets[i]` 字段

| 属性 | 类型 | 说明 |
|------|------|------|
| `petId` | string | 宠物 ID |
| `petName` | string | 宠物名字 |
| `petType` | integer | 1=猫，2=狗，3=异宠 |
| `petTypeText` | string | 展示文案 |
| `breed` | string | 品种 |
| `ageText` | string | 年龄文案，如 `"2岁3个月"` |
| `avatarUrl` | string | 宠物头像 URL |
| `careNotes` | string | 护理备注（可为空）|

**响应示例**

```json
{
  "code": 0, "message": "ok",
  "data": {
    "orderId": "10086",
    "orderStatus": 4,
    "orderStatusText": "履约中",
    "serviceItems": [{ "serviceType": 1, "serviceTypeText": "上门喂猫" }],
    "serviceDate": "2026-05-23",
    "serviceTimeSlot": "14:00 - 15:00",
    "totalAmount": "120.00",
    "address": {
      "fullAddress": "静安区延安中路 888 号 3 单元 1501",
      "district": "静安区",
      "lat": 31.2304,
      "lng": 121.4737
    },
    "owner": {
      "nickname": "小花",
      "avatarUrl": "https://cdn.example.com/avatar/u001.jpg",
      "phone": "138****8888"
    },
    "pets": [{
      "petId": "p001",
      "petName": "咪咪",
      "petType": 1,
      "petTypeText": "猫",
      "breed": "英短",
      "ageText": "2岁3个月",
      "avatarUrl": "https://cdn.example.com/pet/p001.jpg",
      "careNotes": "每天喂两次，早晚各一次，每次 50g 干粮"
    }],
    "serviceNotes": "家里有备用钥匙在门口鞋柜上",
    "completedNodeTypes": [1, 2],
    "createdAt": "2026-05-20 10:15:00"
  }
}
```

**Dart 对应**：`CaretakerOrderDetail`（`caretaker_order_detail_model.dart`）/ `GetCaretakerOrderDetailUseCase` / `CaretakerOrderDetailScreen`

---

## API-22 履约异常-宠托师自报

```
POST /api/v1/caretaker/orders/{orderId}/exception/self-report
```

> 宠托师在履约过程中主动上报异常（如人身安全威胁、门禁异常、宠物异常等）。  
> 调用后：后端将订单置为异常等待状态，并向宠主发送官方消息通知。

### Path 参数

| 属性 | 类型 | 说明 |
|------|------|------|
| `orderId` | string | 订单 ID |

### 请求 Body

| 属性 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `exceptionType` | integer | 是 | 异常类型，见下表 |
| `description` | string | 是 | 异常描述 |

**exceptionType 枚举**

| 值 | 前端文案 |
|----|---------|
| `1` | 人身安全威胁 |
| `2` | 财产环境危机 |
| `3` | 单主严重违规 |
| `4` | 门禁/入户异常 |
| `5` | 其他 |

**请求示例**

```json
{
  "exceptionType": 4,
  "description": "现场门禁异常，暂时无法进入"
}
```

### 响应 `data`

`data` 为 `null`，`success=true` 表示上报成功。

**Dart 对应**：待实现（`fulfillment_remote_data_source.dart` 新增方法）

---

## API-23 履约异常-无责撤单

```
POST /api/v1/caretaker/orders/{orderId}/exception/no-fault-retreat
```

> 宠托师异常上报后，宠主超时未处理时申请无责退出订单，不计入信用扣分。  
> **后端会校验是否已达到宠主响应超时时间**，超时前调用会报错。  
> 当前资金赔偿/退款规则后端尚未完整实现，仅记录撤退行为。

### Path 参数

| 属性 | 类型 | 说明 |
|------|------|------|
| `orderId` | string | 订单 ID |

### 请求 Body

**无请求体。**

### 响应 `data`

`data` 为 `null`，`success=true` 表示申请成功。

**Dart 对应**：待实现（`fulfillment_remote_data_source.dart` 新增方法）

---

## API-24 官方消息

```
GET /api/v1/messages/official?orderId={orderId}
```

> 查询订单相关的官方系统消息，用于「消息」页面中的系统通知展示。

### Query 参数

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `orderId` | string | 是 | 订单 ID |

### 响应 `data`

官方消息列表（数组）：

| 属性 | 类型 | 说明 |
|------|------|------|
| `messageId` | integer/string | 消息 ID |
| `orderId` | integer/string | 关联订单 ID |
| `content` | string | 消息内容 |
| `createdAt` | string | 创建时间，`YYYY-MM-DD HH:mm:ss` |

**响应示例**

```json
{
  "code": "0", "message": "success", "success": true,
  "data": [
    {
      "messageId": "9001",
      "orderId": "10086",
      "content": "您的订单已被宠主确认，服务正式开始。",
      "createdAt": "2026-05-20 14:00:00"
    }
  ]
}
```

**Dart 对应**：待实现（`caretaker_messages_screen.dart` 新增官方消息区块）

---

## API-36 申请成为宠托师

```
POST /api/v1/me/apply-caretaker
```

> **前端约定接口，后端待实现。**  
> 宠物主（roleType=1）点击「成为宠托师」时调用，后端将用户 roleType 升级为 `2`（宠托师）。  
> 若用户已是宠托师（roleType=2 或 3），后端幂等处理，仍返回 `success=true`。

### 请求 Body

空 body，或传 `{}`。

### 响应 `data`

`data` 为 `null`，以 `success=true` 表示申请成功。

```json
{
  "code": "0",
  "message": "success",
  "success": true,
  "data": null
}
```

**Dart 对应**：`ApplyCaretakerRemoteDataSource`（`lib/features/auth/data/datasources/apply_caretaker_remote_data_source.dart`）

---

## API-25 实名认证提交

```
POST /api/v1/me/real-name-verify
```

> **前端约定接口，后端待实现。**  
> 提交宠托师实名信息，包含真实姓名、身份证号及身份证正反面照片（图片选填）。认证通过后，`certTags` 中将出现 `"实名认证"` 标签，同时满足平台培训前置条件。

### 请求 Body

| 属性 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `realName` | string | 是 | 真实姓名，2 字以上 |
| `idCardNo` | string | 是 | 身份证号码，18 位，末位可为 `X`，需通过加权校验码验证；年龄须 18–60 岁 |
| `frontImageUrl` | string | 否 | 身份证正面（人像面）图片 URL，由 `POST /api/v1/upload/image` 上传后获得 |
| `backImageUrl` | string | 否 | 身份证背面（国徽面）图片 URL |

**请求示例**

```json
{
  "realName": "张三",
  "idCardNo": "110101199001010011",
  "frontImageUrl": "https://oss.example.com/idcard/front_xxx.jpg",
  "backImageUrl": "https://oss.example.com/idcard/back_xxx.jpg"
}
```

### 响应 `data`

`data` 为 `null`，以 `success=true` 表示提交成功。

```json
{
  "code": "0",
  "message": "success",
  "success": true,
  "data": null
}
```

### 前端校验规则（客户端在提交前验证，后端同样需要校验）

| 规则 | 说明 |
|------|------|
| 正则格式 | `^[1-9]\d{5}(18\|19\|20)\d{2}(0[1-9]\|1[0-2])(0[1-9]\|[12]\d\|3[01])\d{3}[\dXx]$` |
| 加权校验码 | 权重 `[7,9,10,5,8,4,2,1,6,3,7,9,10,5,8,4,2]`，余数映射表 `['1','0','X','9','8','7','6','5','4','3','2']` |
| 年龄范围 | 从第 7–14 位提取出生日期，要求当前年龄 18–60 周岁（含） |

**Dart 对应**：`CaretakerVerificationRemoteDataSource`（`caretaker_verification_remote_data_source.dart`）/ `CaretakerVerificationScreen`

---

## 平台培训认证（API-26 ~ API-30）

宠托师完成实名认证（API-25）后，需通过平台培训与资格考试，方可获得接单资格。

### 认证流程

```
实名认证（API-25）
    ↓ realNameVerified = true
开始学习（API-27）→ 阅读培训材料（前端 /caretaker/training/study）
    ↓ 滚动至底部后点击「已读完，去考试」
完成学习（API-28）→ learningCompletedAt 有值
    ↓
开始考试（API-29）→ 20 道单选题（15 基础 + 5 核心）
    ↓ 提交答案（API-30）
通过 → verifyStatus = 2，获得接单资格
未通过 → verifyStatus 保持 1，可重新学习后重考
```

### 考核规则

| 规则 | 说明 |
|------|------|
| 题目数量 | 共 20 道单选题，随机抽取 |
| 题目构成 | 15 道基础题 + 5 道核心安全题 |
| 分值 | 总分 100，每题 5 分 |
| 合格线 | 得分 ≥ 90 分 |
| 一票否决 | 5 道核心题（`questionType = 2`）错任意 1 道即不通过（`corePassed = false`） |
| 动态重置 | 被投诉或长期未接单时，后端可能重置认证（`resetReason` 有值），需重新学习并考试 |

### 前端路由

| 路由 | 页面 | 说明 |
|------|------|------|
| `/caretaker/training` | `CaretakerTrainingScreen` | 培训总览：步骤进度、考核说明、操作入口 |
| `/caretaker/training/study` | `CaretakerStudyScreen` | 学习材料：调用 API-27 展示正文，滚动到底后调用 API-28 |
| `/caretaker/training/exam` | `CaretakerExamScreen` | 资格考试：调用 API-29 拉题，API-30 交卷 |

### 主页入口卡片（`caretaker_home_screen.dart`）

主页统计卡片下方始终展示培训入口，根据 API-26 返回状态动态显示：

| 条件 | 卡片文案 | 按钮 |
|------|---------|------|
| `verifyStatus = 2` | 认证已通过 | 查看详情 |
| `learningCompletedAt != null` 且未通过 | 学习已完成，待考试 | 去考试 |
| `verifyStatus = 1` 且未完成学习 | 培训进行中 | 继续学习 |
| 其他 | 尚未开始培训 | 去认证 |

**Dart 数据源**：`CaretakerTrainingRemoteDataSource`（`caretaker_training_remote_data_source.dart`）  
**Dart 模型**：`TrainingStatus` / `TrainingMaterial` / `ExamQuestion` / `ExamResult`（同文件内定义）

> 所有接口均需 `Authorization: Bearer <token>` 请求头。

---

## API-26 查询认证状态

```
POST /api/v1/users/training/status
```

> 查询当前宠托师的实名认证状态及平台培训/考试进度。  
> **注意**：HTTP 方法为 `POST`，但语义为查询，无请求 Body。

### 响应 `data`

| 属性 | 类型 | 说明 |
|------|------|------|
| `verifyStatus` | integer | 认证状态：`0`=未开始，`1`=学习中，`2`=已通过 |
| `realNameVerified` | boolean | 是否已完成实名认证（有 `realName` + `idCardNo`） |
| `learningCompletedAt` | string/null | 完成学习的时间，`YYYY-MM-DD HH:mm:ss`；未完成为 `null` |
| `lastExamScore` | integer/null | 最近一次考试得分（0–100）；未参加为 `null` |
| `lastExamPassed` | boolean/null | 最近一次考试是否通过；未参加为 `null` |
| `lastExamAt` | string/null | 最近一次考试时间；未参加为 `null` |
| `resetReason` | string/null | 认证被重置的原因；未重置为 `null` |

### 前端字段映射

| 后端字段 | 前端 `TrainingStatus` 属性 | 说明 |
|---------|---------------------------|------|
| `verifyStatus` | `verifyStatus` | 直接映射 |
| `realNameVerified` | `realNameVerified` | 直接映射 |
| `learningCompletedAt` | `learningCompleted` | 前端转为 `bool`：`!= null` 即为已完成学习 |
| `lastExamScore` | `lastExamScore` | 直接映射 |
| `lastExamPassed` | `lastExamPassed` | 直接映射 |
| `resetReason` | `resetReason` | 直接映射 |

**前端派生属性**：

- `isPassed`：`verifyStatus == 2`
- `canStartExam`：`learningCompleted && !isPassed`

**响应示例**

```json
{
  "code": "0", "message": "success", "success": true,
  "data": {
    "verifyStatus": 1,
    "realNameVerified": true,
    "learningCompletedAt": "2026-06-01 14:30:00",
    "lastExamScore": 85,
    "lastExamPassed": false,
    "lastExamAt": "2026-06-01 15:00:00",
    "resetReason": null
  }
}
```

**Dart 对应**：`CaretakerTrainingRemoteDataSource.getStatus()` → `TrainingStatus`  
**调用页面**：`CaretakerHomeScreen`（主页卡片）、`CaretakerTrainingScreen`（培训总览）

---

## API-27 开始平台培训

```
POST /api/v1/users/training/start
```

> 返回平台培训材料内容，同时将用户标记为培训进行中。  
> **前提**：`realNameVerified = true`（需先完成 API-25 实名认证）。  
> 无请求 Body。

### 响应 `data`

| 属性 | 类型 | 说明 |
|------|------|------|
| `materialId` | integer (int64) | 培训材料 ID |
| `title` | string | 培训材料标题 |
| `content` | string | 培训材料正文（纯文本，含宠物行为学、入户流程、应急预案等） |

**响应示例**

```json
{
  "code": "0", "message": "success", "success": true,
  "data": {
    "materialId": 1,
    "title": "宠托师平台培训手册",
    "content": "第一章 宠物行为学基础\n..."
  }
}
```

**Dart 对应**：`CaretakerTrainingRemoteDataSource.startTraining()` → `TrainingMaterial`  
**调用页面**：`CaretakerStudyScreen`（进入学习页时自动调用）

---

## API-28 完成平台培训

```
POST /api/v1/users/training/complete
```

> 标记当前用户已完成学习，`learningCompletedAt` 写入当前时间，`verifyStatus` 置为 `1`（学习中）。  
> 响应 `data` 为 `null`。

**前提**：`realNameVerified = true`，且用户已进入学习流程（调用过 API-27）

**响应示例**

```json
{
  "code": "0", "message": "success", "success": true,
  "data": null
}
```

**Dart 对应**：`CaretakerTrainingRemoteDataSource.completeTraining()`  
**调用页面**：`CaretakerStudyScreen`（用户滚动至材料底部后点击「已读完，去考试」时调用，成功后跳转考试页）

---

## API-29 开始资格考试

```
POST /api/v1/users/training/exam/start
```

> 返回 20 道考题（15 道基础题 + 5 道核心题），每次调用随机抽题。  
> **前提**：`realNameVerified = true` 且 `learningCompletedAt != null`（已完成 API-28）。  
> 无请求 Body。

### 响应 `data`

| 属性 | 类型 | 说明 |
|------|------|------|
| `questions` | array | 题目列表，固定 20 道 |
| `questions[].questionId` | integer (int64) | 题目 ID，提交答案时使用 |
| `questions[].questionType` | integer | 题型：`1`=基础题，`2`=核心安全题（错 1 题即不通过） |
| `questions[].content` | string | 题目内容 |
| `questions[].options` | array\<string\> | 选项列表（单选，选项为完整文本，非 A/B/C/D 字母） |

**响应示例**

```json
{
  "code": "0", "message": "success", "success": true,
  "data": {
    "questions": [
      {
        "questionId": 101,
        "questionType": 1,
        "content": "遇到宠物应激反应时，正确的做法是？",
        "options": [
          "立即强行抱起安抚",
          "保持安全距离，等待宠物平静",
          "大声呵斥制止",
          "快速离开服务现场"
        ]
      },
      {
        "questionId": 205,
        "questionType": 2,
        "content": "发现宠物误食异物时，应首先？",
        "options": [
          "自行催吐",
          "立即联系宠物主并建议就医",
          "继续完成服务",
          "等待观察再决定"
        ]
      }
    ]
  }
}
```

**Dart 对应**：`CaretakerTrainingRemoteDataSource.startExam()` → `List<ExamQuestion>`  
**调用页面**：`CaretakerExamScreen`（进入考试页时自动调用）

---

## API-30 提交考试答案

```
POST /api/v1/users/training/exam/submit
```

> 提交答卷，返回得分与是否通过。总分 100，每题 5 分（共 20 题），**得分 ≥ 90 且核心题全对**才算通过，`verifyStatus` 变为 `2`。  
> 不通过时 `verifyStatus` 保持 `1`，可重新学习（API-27/28）后再次调用 API-29 重考。

### 请求 Body

| 属性 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `answers` | array | 是 | 答案列表，需包含全部 20 道题 |
| `answers[].questionId` | integer (int64) | 是 | 题目 ID（来自 API-29） |
| `answers[].answer` | string | 是 | 所选选项的**完整文本**（与 `options[]` 中某一项完全一致，非 A/B/C/D 字母） |

**请求示例**

```json
{
  "answers": [
    { "questionId": 101, "answer": "保持安全距离，等待宠物平静" },
    { "questionId": 205, "answer": "立即联系宠物主并建议就医" }
  ]
}
```

### 响应 `data`

| 属性 | 类型 | 说明 |
|------|------|------|
| `score` | integer | 本次得分（0–100） |
| `passed` | boolean | 是否通过（`score >= 90` 且 `corePassed = true`） |
| `corePassed` | boolean | 5 道核心安全题是否全部答对 |

**响应示例（通过）**

```json
{
  "code": "0", "message": "success", "success": true,
  "data": {
    "score": 95,
    "passed": true,
    "corePassed": true
  }
}
```

**响应示例（核心题未全对）**

```json
{
  "code": "0", "message": "success", "success": true,
  "data": {
    "score": 85,
    "passed": false,
    "corePassed": false
  }
}
```

**Dart 对应**：`CaretakerTrainingRemoteDataSource.submitExam(Map<int, String>)` → `ExamResult`  
**调用页面**：`CaretakerExamScreen`（用户答完 20 题后点击「交卷」时调用）

---

## API-31 查询订单结算记录

```
GET /api/v1/orders/{orderId}/settlement
```

> 宠托师或宠主查询当前订单的托管/结算记录，了解入账金额和佣金情况。  
> 调用时机：订单状态为 `6=已完成` 后，订单详情页展示「已入账」信息。

### Path 参数

| 属性 | 类型 | 说明 |
|------|------|------|
| `orderId` | long | 订单 ID |

### 响应 `data`

| 属性 | 类型 | 说明 |
|------|------|------|
| `settlementId` | long | 结算记录 ID |
| `orderId` | long | 订单 ID |
| `ownerId` | long | 宠主 ID |
| `providerId` | long | 服务者 ID |
| `grossAmount` | string | 订单托管总金额 |
| `commissionRate` | string | 平台佣金比例（仅展示，前端不可修改） |
| `commissionAmount` | string | 平台佣金金额 |
| `providerIncome` | string | 服务者实收金额 |
| `settlementStatus` | integer | 结算状态：`1=托管中`，`2=已结算` |
| `settlementStatusDesc` | string | 结算状态文案 |
| `settledAt` | string | 结算完成时间 |

**响应示例**

```json
{
  "code": "0",
  "message": "success",
  "data": {
    "settlementId": 15001,
    "orderId": 2001,
    "ownerId": 1001,
    "providerId": 1002,
    "grossAmount": "168.00",
    "commissionRate": "0.30",
    "commissionAmount": "50.40",
    "providerIncome": "117.60",
    "settlementStatus": 2,
    "settlementStatusDesc": "已结算",
    "settledAt": "2026-06-05 12:00:00"
  }
}
```

**Dart 对应**：待实现（`caretaker_income_screen` 或订单详情页展示结算信息）

---

## API-32 查看我的评价列表

```
GET /api/v1/caretaker/me/reviews
```

> 宠托师个人中心查看收到的评价列表，支持按状态筛选和低分评价单独查看。  
> 调用时机：个人中心 → 我的评价。

### Query 参数

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `page` | integer | 否 | 页码，默认 `1` |
| `pageSize` | integer | 否 | 每页数量，默认 `10`，最大 `50` |
| `reviewStatus` | integer | 否 | 评价状态筛选，不传则返回全部 |
| `lowScoreOnly` | boolean | 否 | `true` 只返回低分评价（任一维度 ≤ 3） |

### 响应 `data`

| 属性 | 类型 | 说明 |
|------|------|------|
| `total` | long | 总数 |
| `page` | integer | 当前页码 |
| `pageSize` | integer | 每页数量 |
| `list` | array | 评价列表 |
| `list[].reviewId` | long | 评价 ID |
| `list[].orderId` | long | 订单 ID |
| `list[].serviceDate` | string | 服务日期 |
| `list[].pets` | array | 宠物摘要：`petName`、`petType`、`petTypeDesc` |
| `list[].overallScore` | integer | 综合评分（1-5） |
| `list[].punctualityScore` | integer | 准时度评分（1-5） |
| `list[].professionalScore` | integer | 专业度评分（1-5） |
| `list[].comment` | string | 文字评价 |
| `list[].deductionReasons` | array | 扣分理由列表，见下表 |
| `list[].attachments` | array | 评价附件列表，含 `url`、`mediaType` 等 |
| `list[].reviewStatus` | integer | 评价状态，见下表 |
| `list[].reviewStatusDesc` | string | 评价状态文案 |
| `list[].canAppeal` | boolean | 是否可发起申诉 |
| `list[].appealUnavailableReason` | string/null | 不可申诉原因 |
| `list[].appealDeadline` | string/null | 申诉截止时间 |
| `list[].createdAt` | string | 评价创建时间 |

**评价状态枚举**

| reviewStatus | reviewStatusDesc |
|------|------|
| `1` | 正常 |
| `2` | 申诉中 |
| `3` | 申诉成立 |
| `4` | 申诉驳回 |
| `5` | 已隐藏 |
| `6` | 已修正 |

**扣分理由枚举（`deductionReasons[].reasonType`）**

| reasonType | reasonTypeDesc |
|------|------|
| `1` | 未按时到达 |
| `2` | 未按要求喂食 |
| `3` | 宠物异常未及时反馈 |
| `4` | 打卡记录缺失 |
| `5` | 服务态度差 |
| `6` | 其他 |

**Dart 对应**：待实现（`caretaker_reviews_screen.dart` 新增）

---

## API-33 查看评价统计

```
GET /api/v1/caretaker/me/reviews/stats
```

> 宠托师个人中心查看评价统计汇总，用于展示综合评分、低分率等。

### 响应 `data`

| 属性 | 类型 | 说明 |
|------|------|------|
| `reviewCount` | long | 评价总数 |
| `overallAvg` | decimal | 综合评分均值 |
| `punctualityAvg` | decimal | 准时度均值 |
| `professionalAvg` | decimal | 专业度均值 |
| `lowScoreCount` | long | 低分评价数量 |
| `lowScoreRate` | decimal | 低分率（0~1） |
| `recent30DayReviewCount` | long | 近 30 天评价数 |
| `recent30DayLowScoreCount` | long | 近 30 天低分评价数 |

**Dart 对应**：待实现（与 API-32 页面配合展示统计卡片）

---

## API-34 查询评价申诉资格

```
GET /api/v1/caretaker/me/reviews/{reviewId}/appeal-eligibility
```

> 宠托师进入评价详情页时调用，判断该评价是否允许发起申诉。

### Path 参数

| 属性 | 类型 | 说明 |
|------|------|------|
| `reviewId` | long | 评价 ID |

### 响应 `data`

| 属性 | 类型 | 说明 |
|------|------|------|
| `reviewId` | long | 评价 ID |
| `canAppeal` | boolean | 是否可申诉 |
| `unavailableReason` | string/null | 不可申诉原因（`canAppeal=false` 时有值） |
| `appealDeadline` | string/null | 申诉截止时间 |

**不可申诉条件（满足任一即不可申诉）**

- 不是低分评价（所有维度均 > 3）
- 没有扣分理由
- 已超过评价创建后 7 天
- 已有进行中的申诉
- 评价不属于当前服务者

**响应示例**

```json
{
  "code": "0",
  "message": "success",
  "data": {
    "reviewId": 11001,
    "canAppeal": true,
    "unavailableReason": null,
    "appealDeadline": "2026-06-12T12:00:00"
  }
}
```

**Dart 对应**：待实现（评价详情页，点击「我要申诉」前先调用）

---

## API-35 发起评价申诉

```
POST /api/v1/caretaker/me/reviews/{reviewId}/appeals
```

> 宠托师针对某条低分评价发起申诉。证据统一作为 `evidenceUrls` 提交，不区分履约证据和补充证据。  
> 申诉成功后评价状态变为 `2=申诉中`，等待平台人工仲裁。

### Path 参数

| 属性 | 类型 | 说明 |
|------|------|------|
| `reviewId` | long | 评价 ID |

### 请求 Body

| 属性 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `reason` | string | 是 | 申诉原因说明 |
| `evidenceUrls` | array\<string\> | 否 | 证据 URL 列表（可复用已上传的履约打卡截图 URL） |

**请求示例**

```json
{
  "reason": "迟到是由于门禁临时故障，已提前和宠主沟通",
  "evidenceUrls": [
    "https://cdn.example.com/appeals/proof.jpg"
  ]
}
```

### 响应 `data`

| 属性 | 类型 | 说明 |
|------|------|------|
| `appealId` | long | 申诉案卷 ID |
| `appealStatus` | integer | 申诉状态 code |
| `appealStatusDesc` | string | 申诉状态文案 |

**申诉状态枚举**

| appealStatus | appealStatusDesc |
|------|------|
| `1` | 待仲裁 |
| `2` | 取证中 |
| `3` | 已判定 |
| `4` | 申诉成立 |
| `5` | 申诉失败 |

**前端处理**

- 成功后返回评价详情页，展示评价状态为「申诉中」。
- 隐藏「我要申诉」按钮。

**Dart 对应**：待实现（评价详情页申诉表单提交）

---

## 数据流向

```
caretaker_verification_screen →  caretaker_verification_ds       →  API-25（实名认证提交）
                              →  upload_remote_data_source       →  API-10（身份证图片上传）
caretaker_home_screen         →  caretaker_training_remote_ds    →  API-26（主页培训入口卡片）
                              →  caretaker_dashboard_repository  →  API-4, 5, 6, 7, 8
                              →  order_hall_repository           →  API-3（取消报名）
caretaker_training_screen     →  caretaker_training_remote_ds    →  API-26（培训总览）
caretaker_study_screen        →  caretaker_training_remote_ds    →  API-27, API-28（学习材料）
caretaker_exam_screen         →  caretaker_training_remote_ds    →  API-29, API-30（资格考试）
caretaker_order_hall_screen   →  order_hall_repository           →  API-1, 2, 3
caretaker_messages_screen     →  conversation_repository         →  API-13, API-24（官方消息）
caretaker_chat_screen         →  conversation_repository         →  API-14, 15
caretaker_profile_screen      →  caretaker_profile_repository    →  API-16, 17, 18, 19, 20
                              →  caretaker_dashboard_repository  →  API-7, 8
caretaker_withdraw_screen     →  caretaker_profile_repository    →  API-19
caretaker_income_screen       →  caretaker_profile_repository    →  API-18, 20
caretaker_order_detail_screen →  caretaker_dashboard_repository  →  API-21
                              →  settlement_repository           →  API-31（结算记录，6=已完成后展示）
service_check_in_screen       →  fulfillment_repository          →  API-9, 12
                              （API-11 已废弃，nodeType=6 推进为5=待宠主确认）
                              （API-22/23 异常上报，待实现）
caretaker_reviews_screen      →  reviews_repository              →  API-32, 33（评价列表+统计，待实现）
caretaker_review_detail_screen→  reviews_repository              →  API-34, 35（申诉资格+发起申诉，待实现）
```

### 登录路由规则

| `roleType` 值 | 跳转目标 | 说明 |
|---------------|---------|------|
| `2` 或 `3` | `/caretaker` | 已有宠托师角色，直接进宠托师首页 |
| `1` | `/home` | 宠物主，进宠物主首页 |
| 注册新账号 | `/home` | 注册后默认进入宠物主首页，可从「我的」页申请成为宠托师 |

> 注：`/select-role` 角色选择页已废弃并删除。

---

## 代码对应表

| 接口 | Dart 实体 | Model / 数据源文件 |
|------|-----------|------------|
| API-1 | `OrderHallPage` / `OrderHallItem` | `order_hall_item_model.dart` |
| API-2 / API-3 | — | `order_hall_remote_data_source.dart` |
| API-4 | `MyApplication` | `my_application_model.dart` |
| API-5 | `ActiveOrder` | `active_order_model.dart` |
| API-6 | `CaretakerStats` | `caretaker_stats_model.dart` |
| API-7 / API-8 | — | `caretaker_dashboard_remote_data_source.dart` |
| API-9 / API-12 | `FulfillmentRecord` / `FulfillmentRecordModel` | `fulfillment_remote_data_source.dart` |
| API-10 | — | `upload_remote_data_source.dart`（身份证/打卡图片上传共用） |
| API-11 | ~~废弃~~ | 数据层保留，UI 层不调用 |
| API-13 | `Conversation` | `conversation_model.dart` |
| API-14 / API-15 | `ChatMessage` | `chat_message_model.dart` / `conversation_remote_data_source.dart` |
| API-16 / API-17 | `CaretakerProfile` | `caretaker_profile_model.dart` |
| API-18 / API-19 | `CaretakerWallet` | `caretaker_wallet_model.dart` |
| API-20 | `CaretakerIncomeRecord` / `CaretakerIncomeRecordPage` | `caretaker_income_record_model.dart` |
| API-21 | `CaretakerOrderDetail` | `caretaker_order_detail_model.dart` |
| API-22 / API-23 | 待实现 | `fulfillment_remote_data_source.dart` 待新增 |
| API-24 | 待实现 | `caretaker_messages_screen.dart` 待新增 |
| API-31 | `SettlementRecord` | 待新增（`settlement_remote_data_source.dart`） |
| API-32 / API-33 | `ReviewItem` / `ReviewStats` | 待新增（`reviews_remote_data_source.dart`） |
| API-34 / API-35 | `AppealEligibility` / `AppealResult` | 待新增（`reviews_remote_data_source.dart`） |
| API-25 | — | `caretaker_verification_remote_data_source.dart` |
| API-26 | `TrainingStatus` | `caretaker_training_remote_data_source.dart` |
| API-27 | `TrainingMaterial` | `caretaker_training_remote_data_source.dart` |
| API-28 | — | `caretaker_training_remote_data_source.dart` |
| API-29 | `ExamQuestion` | `caretaker_training_remote_data_source.dart` |
| API-30 | `ExamResult` | `caretaker_training_remote_data_source.dart` |

若后端调整字段名或类型，请同步修改本文档、Apifox 与对应 `fromJson` / 调用处。
