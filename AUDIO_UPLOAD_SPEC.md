# 音频上传功能实现文档 (iOS 端指南)

本文档整理了 GBase Knowledge 首页音频上传功能的接口逻辑、参数规范及注意事项，旨在协助 iOS 端实现相同功能。

## 1. 业务流程概述

音频上传流程分为三个标准步骤：

1.  **申请上传 (Apply)**: 向后端注册文件信息，获取 S3 预签名 URL (Pre-signed URL) 和上传 ID。
2.  **执行上传 (Upload)**: 直接将文件二进制流通过 `PUT` 请求上传至 S3（不经过业务后端）。
3.  **完成上传 (Finish)**: 通知后端文件已上传完毕，触发后续处理（如转写、分析等）。

---

## 2. 接口详情

**Base URL**: `https://{hostname}/core-api`
*   开发环境示例: `https://hub-dev.gbase.ai/core-api`

### 步骤 1: 申请上传 (Apply)

*   **接口**: `POST /meeting/recording/upload/apply`
*   **鉴权**: 需要 Bearer Token
*   **功能**: 获取上传凭证

#### 请求参数 (JSON)

| 字段 | 类型 | 必填 | 说明 | 示例值 |
| :--- | :--- | :--- | :--- | :--- |
| `meetingId` | string | 是 | 首页上传固定传 "0"，若关联会议传会议ID | `"0"` |
| `name` | string | 是 | 文件全名（含后缀） | `"recording.m4a"` |
| `extension` | string | 是 | 文件扩展名（不含点） | `"m4a"` |
| `contentHash` | string | 是 | 文件 **SHA-256** 哈希值 (Hex 字符串) | `"a5f3..."` |
| `length` | number | 是 | 文件字节大小 | `102400` |
| `fileType` | string | 是 | 固定值 | `"COMPLETE_RECORDING_FILE"` |
| `fromType` | string | 是 | 固定值 | `"GBASE"` |
| `actualStartAt` | string | 是 | 录音开始时间 (格式: `YYYY-MM-DD HH:mm:ss`) | `"2023-10-27 10:00:00"` |

#### 响应结构

```json
{
  "success": true,
  "data": {
    "id": 12345,                   // [关键] 录音任务 ID，步骤3需要使用
    "uploadUri": "https://s3...",  // [关键] S3 上传地址
    "contentType": "audio/mp4",    // [关键] S3 上传时必须使用的 Content-Type
    "meetingId": "..."
  }
}
```

---

### 步骤 2: 上传文件至 S3 (S3 PUT)

*   **接口**: 使用步骤 1 返回的 `uploadUri`
*   **Method**: `PUT`
*   **鉴权**: 无需业务 Token（签名已包含在 URL 中）

#### 请求头 (Headers)

*   `Content-Type`: **必须**与步骤 1 响应中的 `contentType` 完全一致。如果不一致，AWS S3 会返回 `SignatureDoesNotMatch` 错误。

#### 请求体 (Body)

*   文件的原始二进制数据 (Binary Data)。

---

### 步骤 3: 完成上传 (Finish)

*   **接口**: `POST /meeting/recording/upload/finish`
*   **鉴权**: 需要 Bearer Token
*   **功能**: 确认上传完成，触发服务端任务

#### 请求参数 (JSON)

| 字段 | 类型 | 必填 | 说明 |
| :--- | :--- | :--- | :--- |
| `id` | number | 是 | 步骤 1 返回的 `id` |
| `contentHash` | string | 是 | 与步骤 1 相同的 SHA-256 哈希值 |

#### 响应结构

```json
{
  "success": true,
  "data": null
}
```

---

## 3. iOS 开发注意事项

### 1. 哈希算法 (Critical)
前端代码中的 `calculateMD5` 函数名具有误导性，实际实现使用的是 **SHA-256** 算法。
*   **Web端实现**: `crypto.subtle.digest("SHA-256", arrayBuffer)`
*   **iOS端要求**: 请务必对文件内容计算 SHA-256 Hex 字符串，不要使用 MD5。

### 2. 时间格式
`actualStartAt` 字段要求格式为 `YYYY-MM-DD HH:mm:ss` (例如 `2023-10-27 14:30:00`)。
*   请确保不要带 `T` 或毫秒，需要进行格式化处理。

### 3. S3 上传失败处理
*   如果 S3 上传失败（非 2xx 响应），**不要**调用步骤 3 的 finish 接口。
*   常见错误是 `Content-Type` 不匹配，请检查 iOS 网络库（如 Alamofire）是否自动修改了该 Header。

### 4. 录音格式
*   iOS 建议录制为 `.m4a` (AAC) 格式，体积小且兼容性好。
*   对应的 `extension` 参数传 `"m4a"`。

## 4. iOS 伪代码示例 (Swift)

```swift
func uploadAudio(fileUrl: URL) async throws {
    // 1. 准备文件数据与哈希
    let fileData = try Data(contentsOf: fileUrl)
    let sha256String = calculateSHA256(data: fileData) // 需自行实现 SHA256
    let fileSize = fileData.count
    let fileName = fileUrl.lastPathComponent
    let fileExtension = fileUrl.pathExtension
    
    // 2. Step 1: 申请上传
    let applyParams: [String: Any] = [
        "meetingId": "0",
        "name": fileName,
        "extension": fileExtension,
        "contentHash": sha256String,
        "length": fileSize,
        "fileType": "COMPLETE_RECORDING_FILE",
        "fromType": "GBASE",
        "actualStartAt": formatDate(Date()) // yyyy-MM-dd HH:mm:ss
    ]
    
    let applyResponse = try await NetworkManager.post("/meeting/recording/upload/apply", parameters: applyParams)
    guard let uploadInfo = applyResponse.data else { throw UploadError.applyFailed }
    
    // 3. Step 2: 上传 S3
    var request = URLRequest(url: URL(string: uploadInfo.uploadUri)!)
    request.httpMethod = "PUT"
    request.setValue(uploadInfo.contentType, forHTTPHeaderField: "Content-Type")
    request.httpBody = fileData
    
    let (_, response) = try await URLSession.shared.data(for: request)
    guard let httpResp = response as? HTTPURLResponse, (200...299).contains(httpResp.statusCode) else {
        throw UploadError.s3UploadFailed
    }
    
    // 4. Step 3: 完成通知
    let finishParams: [String: Any] = [
        "id": uploadInfo.id,
        "contentHash": sha256String
    ]
    
    let finishResponse = try await NetworkManager.post("/meeting/recording/upload/finish", parameters: finishParams)
    if !finishResponse.success {
        throw UploadError.finishFailed
    }
    
    print("上传流程完成")
}
```
