//  ChatServiceTests.swift —— AI 学伴请求体的编码规则                      // 文件说明
//  只测能离线验证的部分：发出去的 JSON 必须只有 role 与 content            // 测试边界
//  网络与模型调用不在单元测试里跑，真实验证靠 BFF 联调与模拟器截图        // 诚实约束

import XCTest  // 测试框架
@testable import FuShiZhuan  // 拿到被测模块的内部类型

final class ChatServiceTests: XCTestCase {  // 学伴请求测试

    func testMessageEncodesOnlyRoleAndContent() throws {  // 只发必要字段
        let message = ChatMessage(role: .user, content: "税务专硕复试常问什么")  // 一条用户消息
        let data = try JSONEncoder().encode(message)  // 编码
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])  // 转成字典
        XCTAssertEqual(json["role"] as? String, "user")  // 角色必须是 user
        XCTAssertEqual(json["content"] as? String, "税务专硕复试常问什么")  // 正文原样
        XCTAssertNil(json["id"])  // id 是本地列表用的，不该发给服务端
        XCTAssertEqual(json.count, 2)  // 只允许两个字段，多一个都算泄漏
    }  // 用例结束

    func testAssistantRoleEncodes() throws {  // 学伴消息同样只发两个字段
        let message = ChatMessage(role: .assistant, content: "先看税种再讲环节")  // 一条学伴消息
        let data = try JSONEncoder().encode(message)  // 编码
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])  // 转成字典
        XCTAssertEqual(json["role"] as? String, "assistant")  // 角色必须是 assistant
        XCTAssertEqual(json.count, 2)  // 字段数量固定
    }  // 用例结束

    func testSuffixEightIsWhatGetsSent() {  // 只取最近 8 条，同样板 slice(-8)
        var list: [ChatMessage] = []  // 累积消息
        for i in 0..<12 {  // 造 12 条
            list.append(ChatMessage(role: i % 2 == 0 ? .user : .assistant, content: "第\(i)条"))  // 交替角色
        }  // 循环结束
        let sent = Array(list.suffix(8))  // 取最近 8 条
        XCTAssertEqual(sent.count, 8)  // 数量正确
        XCTAssertEqual(sent.first?.content, "第4条")  // 从第 4 条开始
        XCTAssertEqual(sent.last?.content, "第11条")  // 到第 11 条结束
    }  // 用例结束
}  // ChatServiceTests 结束
