//  QuizExplainService.swift —— AI 讲题                                // 文件说明
//  只做一件事：把一道客观题发给 BFF，拿回讲解、要点、记忆钩子           // 职责约束
//  Key 不在客户端，也不需要；Key 只在 BFF 服务器上                     // 安全说明

import Foundation  // 基础库

struct QuizExplainRequest: Encodable {  // 讲题请求
    let questionId: String  // 题目 id，BFF 用它做幂等键
    let stem: String  // 题干
    let options: [String]  // 选项
    let answer: [Int]  // 正确答案下标
    let picked: [Int]  // 我选的下标
    let explain: String  // 题库自带解析，供模型参考
}  // QuizExplainRequest 结束

struct QuizExplainResponse: Decodable {  // 讲题结果
    let explain: String  // 讲解正文
    let keyPoints: [String]  // 可背要点
    let hook: String?  // 记忆钩子
    let disclaimer: String?  // 免责声明
}  // QuizExplainResponse 结束

struct QuizExplainService {  // 讲题服务
    private let baseURL = AppConfig.bffBaseURL  // 服务地址
    private let token = AppConfig.serviceToken  // 客户端令牌
    private let deviceID = AppConfig.deviceID  // 设备标识

    func explain(_ body: QuizExplainRequest) async throws -> QuizExplainResponse {  // 请求讲解
        guard let url = URL(string: "/v1/quiz/explain", relativeTo: baseURL) else {  // 拼地址
            throw AppError.network("服务地址不合法")  // 地址错误
        }  // 分支结束
        var req = URLRequest(url: url)  // 造请求
        req.httpMethod = "POST"  // 方法
        req.timeoutInterval = AppConfig.requestTimeout  // 与 BFF 超时对齐
        req.setValue("application/json", forHTTPHeaderField: "content-type")  // 请求体类型
        req.setValue(deviceID, forHTTPHeaderField: "x-device-id")  // 设备标识
        req.setValue(token, forHTTPHeaderField: "x-service-token")  // 令牌
        req.httpBody = try JSONEncoder().encode(body)  // 序列化请求体

        let data: Data  // 响应数据
        let response: URLResponse  // 响应对象
        do {  // 尝试发请求
            (data, response) = try await URLSession.shared.data(for: req)  // 异步请求
        } catch let error as URLError {  // 网络层错误
            if error.code == .timedOut { throw AppError.timeout }  // 超时单独归
            throw AppError.network(error.localizedDescription)  // 其它归网络失败
        } catch {  // 非网络错误
            throw AppError.network(String(describing: error))  // 统一归网络
        }  // 分支结束

        let status = (response as? HTTPURLResponse)?.statusCode ?? 0  // 状态码
        guard status == 200 else {  // 非 200 视为失败
            if status == 401 { throw AppError.unauthorized }  // 令牌不对
            if status == 429 { throw AppError.quotaExceeded }  // 额度用完
            if status == 504 { throw AppError.timeout }  // 上游超时
            let text = String(data: data, encoding: .utf8) ?? ""  // 错误体
            throw AppError.aiUnavailable(text.isEmpty ? "HTTP \(status)" : String(text.prefix(120)))  // 归为 AI 不可用
        }  // 分支结束
        return try JSONDecoder().decode(QuizExplainResponse.self, from: data)  // 解析并返回
    }  // explain 结束
}  // QuizExplainService 结束
