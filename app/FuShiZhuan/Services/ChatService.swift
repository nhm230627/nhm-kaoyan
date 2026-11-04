//  ChatService.swift —— AI 学伴多轮对话（打 BFF /v1/chat）              // 文件说明
//  只做一件事：把「最近几条消息」发给 BFF，拿回一段纯文本回复              // 职责说明
//  Key 不在客户端；限流与额度由服务端 guard 控制                          // 安全说明

import Foundation  // 基础库

// MARK: - 消息                                                          // 分节：类型

struct ChatMessage: Codable, Identifiable, Equatable {  // 一条对话消息
    enum Role: String, Codable {  // 角色
        case user  // 用户
        case assistant  // 学伴
    }  // Role 结束

    var id = UUID()  // 列表标识
    let role: Role  // 谁说的
    var content: String  // 正文

    private enum CodingKeys: String, CodingKey {  // 只把 role 与 content 发给服务端
        case role  // 角色
        case content  // 正文
    }  // CodingKeys 结束
}  // ChatMessage 结束

private struct ChatResponse: Decodable {  // BFF 返回
    let reply: String  // 回复正文
}  // ChatResponse 结束

// MARK: - 协议                                                          // 分节：协议

protocol ChatReplying {  // 对话能力
    func reply(to messages: [ChatMessage]) async throws -> String  // 发一组消息，拿一段回复
}  // ChatReplying 结束

// MARK: - 真实实现                                                      // 分节：实现

struct RemoteChatService: ChatReplying {  // 打 BFF 的实现
    private let baseURL: URL  // 服务地址
    private let token: String  // 客户端令牌
    private let deviceID: String  // 设备标识
    private let session: URLSession  // 网络会话

    init(  // 构造器
        baseURL: URL = AppConfig.bffBaseURL,  // 默认取配置
        token: String = AppConfig.serviceToken,  // 默认取配置
        deviceID: String = AppConfig.deviceID,  // 默认取配置
        session: URLSession = .shared  // 默认共享会话
    ) {  // 构造体开始
        self.baseURL = baseURL  // 赋值地址
        self.token = token  // 赋值令牌
        self.deviceID = deviceID  // 赋值设备标识
        self.session = session  // 赋值会话
    }  // 构造结束

    private struct Body: Encodable {  // 请求体
        let messages: [ChatMessage]  // 最近几条消息
    }  // Body 结束

    func reply(to messages: [ChatMessage]) async throws -> String {  // 发一组消息
        guard let url = URL(string: "/v1/chat", relativeTo: baseURL) else {  // 拼地址
            throw AppError.network("服务地址不合法")  // 地址错误
        }  // 分支结束

        var request = URLRequest(url: url)  // 造请求
        request.httpMethod = "POST"  // 方法
        request.timeoutInterval = AppConfig.requestTimeout  // 超时
        request.setValue("application/json", forHTTPHeaderField: "content-type")  // 请求体类型
        request.setValue(deviceID, forHTTPHeaderField: "x-device-id")  // 设备标识
        request.setValue(token, forHTTPHeaderField: "x-service-token")  // 令牌
        request.httpBody = try JSONEncoder().encode(Body(messages: Array(messages.suffix(8))))  // 只发最近 8 条，同样板

        let data: Data  // 响应体
        let response: URLResponse  // 响应头
        do {  // 尝试发请求
            (data, response) = try await session.data(for: request)  // 异步请求
        } catch let error as URLError {  // 网络层错误
            throw Self.map(error)  // 翻译成 AppError
        } catch {  // 其它错误
            throw AppError.network(String(describing: error))  // 归为网络失败
        }  // 分支结束

        let status = (response as? HTTPURLResponse)?.statusCode ?? 0  // 状态码
        guard status == 200 else {  // 非 200 视为失败
            switch status {  // 按状态码分诊
            case 400: throw AppError.aiUnavailable("消息不合法，重开面板再试")  // 请求体问题
            case 401: throw AppError.unauthorized  // 令牌不对
            case 429: throw AppError.quotaExceeded  // 额度用完
            case 502: throw AppError.aiUnavailable("模型没答上来，过会儿再试")  // 上游失败
            case 503: throw AppError.aiUnavailable("服务端没配模型密钥")  // 没 Key
            case 504: throw AppError.timeout  // 上游超时
            default: throw AppError.aiUnavailable("服务返回 \(status)")  // 其它
            }  // 分支结束
        }  // 分支结束

        do {  // 尝试解码
            return try JSONDecoder().decode(ChatResponse.self, from: data).reply  // 取正文
        } catch {  // 解码失败
            throw AppError.aiUnavailable("学伴的回复读不出来")  // 明确说明
        }  // 分支结束
    }  // reply 结束

    private static func map(_ error: URLError) -> AppError {  // 网络错误翻译
        switch error.code {  // 按错误码分支
        case .timedOut: return .timeout  // 超时
        case .notConnectedToInternet, .networkConnectionLost: return .network("没有网络连接")  // 断网
        case .cannotFindHost, .cannotConnectToHost: return .network("连不上服务，检查地址或服务是否启动")  // 连不上
        default: return .network(error.localizedDescription)  // 其它
        }  // 分支结束
    }  // map 结束
}  // RemoteChatService 结束
