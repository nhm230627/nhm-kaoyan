//  AIChatView.swift —— AI 学伴对话面板（对齐 Web 样板 ai.js）              // 文件说明
//  结构：消息流（我问右 / 学伴答左）→ 输入框 + 发送                        // 页面结构
//  与样板一致：进面板不自动聚焦（移动端会弹键盘把背景页顶飞）               // 交互约定
//  与样板一致：请求期间禁止重复发送，失败只给可执行提示，不假装成功          // 诚实约束
//  系统提示词在服务端（BFF 的 CHAT_SYSTEM），客户端改不了模型人设           // 安全说明

import SwiftUI  // 界面框架

struct AIChatView: View {  // AI 学伴面板

    var preset: String?  // 进来就自动发的一句（样板 open(preset) 行为）
    var panelTitle = "AI 学伴"  // 面板标题，样板可在「AI 讲题」时改名

    @State private var messages: [ChatMessage] = []  // 已发生的对话
    @State private var input = ""  // 输入框内容
    @State private var busy = false  // 是否正在等回复
    @State private var errorLine: String?  // 失败提示

    private let service: ChatReplying = RemoteChatService()  // 真实服务

    var body: some View {  // 视图主体
        VStack(spacing: 0) {  // 纵向排列，消息流与输入框分开
            log  // 消息流
            Divider()  // 分隔线
            composer  // 输入区
        }  // 排列结束
        .background(Color.appBG)  // 底色
        .navigationTitle(panelTitle)  // 标题
        .navigationBarTitleDisplayMode(.inline)  // 小标题
        .task {  // 首次出现
            if let preset, messages.isEmpty { send(preset) }  // 有预设就自动问一次
        }  // 任务结束
    }  // body 结束

    // MARK: - 消息流                                                  // 分节：消息流

    private var log: some View {  // 消息列表
        ScrollViewReader { proxy in  // 便于滚到底
            ScrollView {  // 可滚动
                VStack(alignment: .leading, spacing: Space.m) {  // 纵向排列
                    if messages.isEmpty && !busy { hint }  // 空态提示
                    ForEach(messages) { message in  // 逐条渲染
                        bubble(message)  // 单条气泡
                            .id(message.id)  // 滚动定位用
                    }  // 遍历结束
                    if busy { thinking }  // 等回复时的占位
                    if let errorLine { errorCard(errorLine) }  // 失败提示
                }  // 排列结束
                .padding(Metrics.pagePadding)  // 内边距
            }  // 滚动结束
            .onChange(of: messages.count) { _, _ in scrollToEnd(proxy) }  // 新消息滚到底
            .onChange(of: busy) { _, _ in scrollToEnd(proxy) }  // 忙碌状态变化也滚
        }  // 滚动容器结束
    }  // log 结束

    private var hint: some View {  // 空态提示
        VStack(alignment: .leading, spacing: Space.xs) {  // 纵向排列
            Text("问点什么")  // 标题
                .font(AppFont.bodyStrong)  // 加粗正文
                .foregroundStyle(Color.textPrimary)  // 主文字色
            Text("比如「税务专硕复试常问哪些方向」「个税综合所得怎么讲才不失分」。答案只给建议，不预测录取结果。")  // 说明，与服务的口径一致
                .font(AppFont.caption)  // 小字
                .foregroundStyle(Color.textSecondary)  // 次文字色
                .fixedSize(horizontal: false, vertical: true)  // 允许换行
        }  // 排列结束
        .frame(maxWidth: .infinity, alignment: .leading)  // 靠左撑满
        .padding(Space.l)  // 内边距
        .background(Color.appCard)  // 卡片白
        .clipShape(RoundedRectangle(cornerRadius: Radius.card, style: .continuous))  // 圆角
    }  // hint 结束

    private func bubble(_ message: ChatMessage) -> some View {  // 单条气泡
        HStack {  // 横向排列
            if message.role == .user { Spacer(minLength: 40) }  // 我问的话靠右
            Text(message.content)  // 正文
                .font(AppFont.body)  // 正文字号
                .foregroundStyle(message.role == .user ? Color.white : Color.textPrimary)  // 我问白字，学伴深字
                .fixedSize(horizontal: false, vertical: true)  // 允许换行
                .padding(Space.m)  // 内边距
                .background(message.role == .user ? Color.appBrand : Color.appCard)  // 我问品牌色，学伴白卡
                .clipShape(RoundedRectangle(cornerRadius: Radius.chip, style: .continuous))  // 圆角
            if message.role == .assistant { Spacer(minLength: 40) }  // 学伴的回答靠左
        }  // 排列结束
        .accessibilityIdentifier(message.role == .user ? "chat-me" : "chat-bot")  // 便于 UI 测试
    }  // bubble 结束

    private var thinking: some View {  // 等回复占位
        HStack(spacing: Space.xs) {  // 横向排列
            ProgressView()  // 转圈
                .controlSize(.small)  // 小号
            Text("正在想…")  // 样板原文
                .font(AppFont.caption)  // 小字
                .foregroundStyle(Color.textSecondary)  // 次文字色
            Spacer(minLength: 0)  // 撑开
        }  // 排列结束
        .padding(Space.m)  // 内边距
        .background(Color.appCard)  // 白卡
        .clipShape(RoundedRectangle(cornerRadius: Radius.chip, style: .continuous))  // 圆角
        .accessibilityIdentifier("chat-thinking")  // 便于 UI 测试
    }  // thinking 结束

    private func errorCard(_ text: String) -> some View {  // 失败提示
        HStack(alignment: .top, spacing: Space.xs) {  // 横向排列
            Image(systemName: "exclamationmark.triangle.fill")  // 警示图标
                .font(.system(size: 12))  // 小图标
                .foregroundStyle(Color.appWarn)  // 警示色
            Text(text)  // 说明
                .font(AppFont.caption)  // 小字
                .foregroundStyle(Color.textSecondary)  // 次文字色
                .fixedSize(horizontal: false, vertical: true)  // 允许换行
            Spacer(minLength: 0)  // 撑开
        }  // 排列结束
        .padding(Space.m)  // 内边距
        .background(Color.appWarn.opacity(0.10))  // 淡橙底
        .clipShape(RoundedRectangle(cornerRadius: Radius.chip, style: .continuous))  // 圆角
        .accessibilityIdentifier("chat-error")  // 便于 UI 测试
    }  // errorCard 结束

    // MARK: - 输入区                                                  // 分节：输入

    private var composer: some View {  // 输入区
        HStack(alignment: .bottom, spacing: Space.s) {  // 横向排列
            TextField("问学伴…", text: $input, axis: .vertical)  // 可换行输入
                .font(AppFont.body)  // 正文字号
                .lineLimit(1...4)  // 最多四行
                .padding(.horizontal, Space.m)  // 左右内边距
                .padding(.vertical, Space.s)  // 上下内边距
                .background(Color.appCard)  // 白底
                .clipShape(RoundedRectangle(cornerRadius: Radius.button, style: .continuous))  // 圆角
                .submitLabel(.send)  // 键盘回车型按钮写「发送」
                .onSubmit { send(input) }  // 回车直接发
                .accessibilityIdentifier("chat-input")  // 便于 UI 测试
            Button {  // 发送按钮
                send(input)  // 发出
            } label: {  // 按钮外观
                Image(systemName: "arrow.up.circle.fill")  // 圆形箭头
                    .font(.system(size: 30))  // 大小
                    .foregroundStyle(canSend ? Color.appBrand : Color.textTertiary)  // 可用才亮
            }  // 标签结束
            .disabled(!canSend)  // 不能发时禁用
            .accessibilityIdentifier("chat-send")  // 便于 UI 测试
        }  // 排列结束
        .padding(Space.m)  // 内边距
        .background(Color.appBG)  // 与页面同色
    }  // composer 结束

    private var canSend: Bool {  // 能不能发
        !busy && !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty  // 不忙且非空
    }  // canSend 结束

    // MARK: - 发送                                                    // 分节：发送

    private func send(_ raw: String) {  // 发一条
        let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)  // 去掉首尾空白
        guard !text.isEmpty, !busy else { return }  // 空的不发，忙的时候也不发
        messages.append(ChatMessage(role: .user, content: text))  // 先落到消息流
        input = ""  // 清空输入框
        errorLine = nil  // 清掉上次错误
        busy = true  // 进入等回复状态
        let snapshot = messages  // 取当前上下文
        Task {  // 异步请求
            do {  // 尝试请求
                let answer = try await service.reply(to: snapshot)  // 问 BFF
                messages.append(ChatMessage(role: .assistant, content: answer))  // 追加回复
            } catch {  // 失败
                errorLine = describe(error)  // 给可执行提示
            }  // 分支结束
            busy = false  // 退出忙碌
        }  // 任务结束
    }  // send 结束

    private func describe(_ error: Error) -> String {  // 错误翻译成一句话
        if let app = error as? AppError {  // 已知错误类型
            return "\(app.title)：\(app.action)"  // 标题 + 下一步
        }  // 分支结束
        return error.localizedDescription  // 其它原样给
    }  // describe 结束

    private func scrollToEnd(_ proxy: ScrollViewProxy) {  // 滚到底
        guard let last = messages.last else { return }  // 没消息就不动
        withAnimation(.easeOut(duration: 0.2)) {  // 轻微动画
            proxy.scrollTo(last.id, anchor: .bottom)  // 定位到最后一条
        }  // 动画结束
    }  // scrollToEnd 结束
}  // AIChatView 结束
