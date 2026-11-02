//  RemoteInterviewService.swift —— 真实服务实现                        // 文件说明
//  只做一件事：把协议方法翻译成 HTTP 请求，把错误翻译成 AppError       // 职责约束
//  Key 不在这里，也不需要；Key 只在 BFF 服务器上                      // 安全说明

import Foundation                                                     // 基础库

struct RemoteInterviewService: InterviewService {                     // 真实实现
    private let baseURL: URL                                          // 服务基地址
    private let token: String                                         // 客户端令牌
    private let deviceID: String                                      // 设备标识
    private let session: URLSession                                   // 网络会话

    init(                                                             // 构造器
        baseURL: URL = AppConfig.bffBaseURL,                          // 默认取配置
        token: String = AppConfig.serviceToken,                       // 默认取配置
        deviceID: String = AppConfig.deviceID,                        // 默认取配置
        session: URLSession = .shared                                 // 默认共享会话
    ) {                                                               // 构造体开始
        self.baseURL = baseURL                                        // 赋值地址
        self.token = token                                            // 赋值令牌
        self.deviceID = deviceID                                      // 赋值设备标识
        self.session = session                                        // 赋值会话
    }                                                                 // 构造结束

    func nextQuestion(_ request: TurnRequest) async throws -> TurnResponse { // 出题
        try await post(path: "/v1/interview/turn", body: request)     // 发请求并解码
    }                                                                 // 方法结束

    func evaluate(_ request: EvaluateRequest) async throws -> EvaluateResponse { // 评分
        try await post(path: "/v1/interview/evaluate", body: request) // 发请求并解码
    }                                                                 // 方法结束

    func summarize(_ request: SummaryRequest) async throws -> SummaryResponse { // 总结
        try await post(path: "/v1/interview/summary", body: request)  // 发请求并解码
    }                                                                 // 方法结束

    /// 统一的 POST + 解码
    private func post<Body: Encodable, Response: Decodable>(           // 泛型请求
        path: String,                                                 // 接口路径
        body: Body                                                    // 请求体
    ) async throws -> Response {                                       // 返回解码结果
        guard let url = URL(string: path, relativeTo: baseURL) else {  // 拼地址
            throw AppError.network("服务地址不合法")                    // 地址错误
        }                                                             // 分支结束

        var request = URLRequest(url: url)                            // 造请求
        request.httpMethod = "POST"                                   // 方法
        request.timeoutInterval = AppConfig.requestTimeout             // 超时
        request.setValue("application/json", forHTTPHeaderField: "content-type") // 请求体类型
        request.setValue(deviceID, forHTTPHeaderField: "x-device-id")  // 设备标识
        request.setValue(token, forHTTPHeaderField: "x-service-token") // 令牌

        let encoder = JSONEncoder()                                   // 编码器
        request.httpBody = try encoder.encode(body)                    // 序列化请求体

        let result: (Data, URLResponse)                               // 请求结果
        do {                                                          // 尝试发请求
            result = try await session.data(for: request)             // 异步请求
        } catch let error as URLError {                               // 网络层错误
            throw Self.mapURLError(error)                             // 翻译成 AppError
        } catch {                                                     // 其它错误
            throw AppError.network(String(describing: error))          // 归为网络失败
        }                                                             // 分支结束
        let data = result.0                                           // 响应数据
        let response = result.1                                       // 响应对象

        let status = (response as? HTTPURLResponse)?.statusCode ?? 0   // 取状态码
        guard status == 200 else {                                    // 非 200 视为失败
            let parsed = try? JSONDecoder().decode(BFFErrorBody.self, from: data) // 解错误体
            throw mapBFFError(status: status, body: parsed)            // 翻译错误
        }                                                             // 分支结束

        do {                                                          // 尝试解码
            return try JSONDecoder().decode(Response.self, from: data) // 解码成功体
        } catch {                                                     // 解码失败
            throw AppError.dataCorrupted("服务返回格式不符：\(error)")  // 归为数据错误
        }                                                             // 分支结束
    }                                                                 // post 结束

    /// URLError 映射
    private static func mapURLError(_ error: URLError) -> AppError {   // 网络错误翻译
        switch error.code {                                           // 按错误码分支
        case .timedOut: return .timeout                               // 超时
        case .notConnectedToInternet, .networkConnectionLost:         // 断网或连接中断
            return .network("网络不可用")                              // 网络失败
        case .cannotConnectToHost, .cannotFindHost:                   // 连不上主机
            return .network("连不上服务，检查 BFF 是否启动")            // 提示更具体
        default: return .network(error.localizedDescription)          // 其它
        }                                                             // 分支结束
    }                                                                 // 方法结束
}                                                                     // RemoteInterviewService 结束
