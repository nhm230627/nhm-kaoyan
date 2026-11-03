//  DiyBankView.swift —— 我的题库（对齐 Web 样板 page-diy）                 // 文件说明
//  结构：三格统计（自建题目/已练过/正确率）→ 手动录题 / AI 生成一道 → 录题表单 → 我的题目列表
//  自建题的 topic 固定为 custom，参与统计但不混进内置题库的板块             // 数据约定
//  「AI 生成一道」样板有，但本机还没有可用的题目生成接口，点了如实提示       // 诚实约束

import SwiftUI  // 界面框架

struct DiyBankView: View {  // 我的题库
    @Environment(AppState.self) private var app  // 读写自建题

    var startWithForm = false  // 进来就展开表单（截图用，正常入口是收起）

    @State private var showingForm = false  // 表单是否展开
    @State private var stem = ""  // 题干
    @State private var type: QuestionType = .single  // 题型
    @State private var options: [String] = ["", ""]  // 选项
    @State private var answerText = ""  // 正确答案（如 A 或 AC）
    @State private var explain = ""  // 解析
    @State private var hint: String?  // 底部轻提示

    private var items: [Question] { app.diyQuestions }  // 自建题

    private var practicedCount: Int {  // 已练过几道（不同题）
        let ids = Set(items.map(\.id))  // 自建题 id
        return Set(app.data.attempts.filter { ids.contains($0.questionID) }.map(\.questionID)).count  // 去过重
    }  // practicedCount 结束

    private var accuracyText: String {  // 正确率
        let ids = Set(items.map(\.id))  // 自建题 id
        let list = app.data.attempts.filter { ids.contains($0.questionID) }  // 相关作答
        guard !list.isEmpty else { return "0%" }  // 还没练过
        let right = list.filter(\.isCorrect).count  // 答对次数
        return "\(Int((Double(right) / Double(list.count) * 100).rounded()))%"  // 百分比
    }  // accuracyText 结束

    var body: some View {  // 视图主体
        ScrollView {  // 可滚动
            VStack(alignment: .leading, spacing: Space.l) {  // 纵向排列
                stats  // 三格统计
                actionRow  // 两个按钮
                if showingForm { form }  // 录题表单
                listSection  // 我的题目
            }  // 排列结束
            .padding(Metrics.pagePadding)  // 内边距
            .padding(.bottom, 96)  // 底部留白：悬浮 TabBar 不占安全区，必须手动让开
        }  // 滚动结束
        .background(Color.appBG)  // 底色
        .navigationTitle("我的题库")  // 标题
        .navigationBarTitleDisplayMode(.inline)  // 内联
        .onAppear { if startWithForm { showingForm = true } }  // 截图时直接展开表单
        .overlay(alignment: .bottom) {  // 轻提示
            if let hint {  // 有提示才显示
                Text(hint)  // 文案
                    .font(AppFont.captionStrong)  // 小字加粗
                    .padding(.horizontal, Space.l)  // 左右内边距
                    .padding(.vertical, Space.s)  // 上下内边距
                    .background(.ultraThinMaterial, in: Capsule())  // 毛玻璃胶囊
                    .padding(.bottom, Space.xxl)  // 距底
                    .transition(.opacity)  // 淡入淡出
            }  // 分支结束
        }  // 浮层结束
    }  // body 结束

    private var stats: some View {  // 三格统计（样板 .diy-top）
        HStack(spacing: Space.s) {  // 横向三等分
            statCell("\(items.count)", "自建题目")  // 自建题数
            statCell("\(practicedCount)", "已练过")  // 练过几道
            statCell(accuracyText, "正确率")  // 正确率
        }  // 排列结束
    }  // stats 结束

    private func statCell(_ value: String, _ title: String) -> some View {  // 一格
        VStack(spacing: 3) {  // 上数字下标题
            Text(verbatim: value)  // 数值
                .font(.system(size: 20, weight: .bold, design: .rounded))  // 圆体加粗
                .foregroundStyle(Color.textPrimary)  // 主色
                .monospacedDigit()  // 等宽
            Text(title)  // 标题
                .font(.system(size: 10.5))  // 小字
                .foregroundStyle(Color.textTertiary)  // 弱化色
        }  // 排列结束
        .frame(maxWidth: .infinity)  // 等分
        .padding(.vertical, 10)  // 上下内边距
        .background(  // 白底
            RoundedRectangle(cornerRadius: 15, style: .continuous)  // 圆角
                .fill(Color.appCard)  // 卡片色
        )  // 背景结束
    }  // statCell 结束

    private var actionRow: some View {  // 两个按钮（样板 row-2）
        HStack(spacing: Space.s) {  // 等分
            PrimaryButton(title: showingForm ? "收起表单" : "手动录题",  // 主按钮
                          systemImage: showingForm ? "chevron.up" : "square.and.pencil") {  // 图标跟着变
                withAnimation { showingForm.toggle() }  // 展开或收起
            }  // 按钮结束

            GhostButton(title: "AI 生成一道", systemImage: "sparkles") {  // 次按钮
                show("题目生成接口还没接，先用「手动录题」")  // 如实提示
            }  // 按钮结束
        }  // 排列结束
    }  // actionRow 结束

    // MARK: - 录题表单                                                // 分节：表单

    private var form: some View {  // 录题表单（样板 .diy-form）
        Card {  // 白卡片
            VStack(alignment: .leading, spacing: Space.m) {  // 纵向排列
                Text("手动录题").font(AppFont.section)  // 表单标题

                field(title: "题干") {  // 题干
                    TextField("输入题目内容", text: $stem, axis: .vertical)  // 多行输入
                        .lineLimit(2...5)  // 最多五行
                        .textFieldStyle(.plain)  // 无边框
                }  // 题干结束

                VStack(alignment: .leading, spacing: Space.xs) {  // 题型
                    Text("题型").font(AppFont.captionStrong)  // 标签
                    HStack(spacing: 4) {  // 三档
                        typeChip(.single, "单选")  // 单选
                        typeChip(.multi, "多选")  // 多选
                        typeChip(.judge, "判断")  // 判断
                    }  // 排列结束
                }  // 题型结束

                VStack(alignment: .leading, spacing: Space.xs) {  // 选项
                    HStack {  // 标题行
                        Text("选项").font(AppFont.captionStrong)  // 标签
                        Spacer(minLength: 0)  // 撑开
                        if type != .judge {  // 判断题不能加选项
                            Button {  // 添加选项
                                if options.count < 6 { options.append("") }  // 最多六个
                            } label: {  // 按钮外观
                                Label("添加", systemImage: "plus.circle")  // 图标加字
                                    .font(.system(size: 12))  // 小字
                                    .foregroundStyle(Color.appBrand)  // 品牌色
                            }  // 外观结束
                            .buttonStyle(.plain)  // 不用默认高亮
                        }  // 分支结束
                    }  // 排列结束

                    ForEach(options.indices, id: \.self) { i in  // 逐项
                        HStack(spacing: Space.xs) {  // 字母 + 输入 + 删除
                            Text(Question.letter(i))  // 字母
                                .font(AppFont.captionStrong)  // 小字加粗
                                .foregroundStyle(Color.textSecondary)  // 次要色
                                .frame(width: 18)  // 固定宽
                            TextField("选项 \(Question.letter(i))", text: Binding(  // 输入框
                                get: { options.indices.contains(i) ? options[i] : "" },  // 读
                                set: { if options.indices.contains(i) { options[i] = $0 } }  // 写
                            ))  // 绑定结束
                            .textFieldStyle(.plain)  // 无边框
                            if type != .judge && options.count > 2 {  // 可删
                                Button {  // 删除这一项
                                    options.remove(at: i)  // 移除
                                } label: {  // 外观
                                    Image(systemName: "minus.circle")  // 减号
                                        .foregroundStyle(Color.appErr)  // 红
                                }  // 外观结束
                                .buttonStyle(.plain)  // 不用默认高亮
                            }  // 分支结束
                        }  // 排列结束
                        .padding(.vertical, 6)  // 上下内边距
                        .padding(.horizontal, 10)  // 左右内边距
                        .background(  // 灰底
                            RoundedRectangle(cornerRadius: 10, style: .continuous)  // 圆角
                                .fill(Color(hex: 0xF7F7FA))  // 样板输入底色
                        )  // 背景结束
                    }  // 遍历结束
                }  // 选项结束

                field(title: "正确答案") {  // 正确答案
                    TextField("如：A 或 AC", text: $answerText)  // 字母输入
                        .textFieldStyle(.plain)  // 无边框
                        .autocorrectionDisabled()  // 关自动更正
                        .textInputAutocapitalization(.characters)  // 自动大写
                }  // 正确答案结束

                field(title: "解析（可留空）") {  // 解析
                    TextField("为什么选它 / 易错点", text: $explain, axis: .vertical)  // 多行
                        .lineLimit(1...4)  // 最多四行
                        .textFieldStyle(.plain)  // 无边框
                }  // 解析结束

                PrimaryButton(title: "保存到我的题库", systemImage: "tray.and.arrow.down") {  // 保存
                    save()  // 校验并写入
                }  // 按钮结束
            }  // 排列结束
        }  // 卡片结束
    }  // form 结束

    private func field<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {  // 一组标签 + 输入
        VStack(alignment: .leading, spacing: Space.xs) {  // 纵向
            Text(title).font(AppFont.captionStrong)  // 标签
            content()  // 输入控件
                .font(AppFont.body)  // 正文字号
                .padding(.vertical, 8)  // 上下内边距
                .padding(.horizontal, 10)  // 左右内边距
                .background(  // 灰底
                    RoundedRectangle(cornerRadius: 10, style: .continuous)  // 圆角
                        .fill(Color(hex: 0xF7F7FA))  // 样板输入底色
                )  // 背景结束
        }  // 排列结束
    }  // field 结束

    private func typeChip(_ t: QuestionType, _ title: String) -> some View {  // 题型胶囊
        let on = type == t  // 是否选中
        return Button {  // 点击切换
            withAnimation {  // 有过渡
                type = t  // 换题型
                if t == .judge { options = ["正确", "错误"] }  // 判断题固定两项
                else if options.count < 2 || options == ["正确", "错误"] { options = ["", ""] }  // 换回来清空
                if t != .multi { answerText = String(answerText.prefix(1)) }  // 非多选只留一个字母
            }  // 动画结束
        } label: {  // 外观
            Text(title)  // 文案
                .font(AppFont.captionStrong)  // 小字加粗
                .foregroundStyle(on ? Color.white : Color.textSecondary)  // 选中白字
                .padding(.horizontal, 13)  // 左右内边距
                .frame(height: 30)  // 与首页 chip 同高
                .background(Capsule().fill(on ? Color.appBrand : Color.appCard))  // 选中实心
        }  // 外观结束
        .buttonStyle(.plain)  // 不用默认高亮
    }  // typeChip 结束

    // MARK: - 列表                                                    // 分节：列表

    private var listSection: some View {  // 我的题目
        VStack(alignment: .leading, spacing: Space.s) {  // 纵向排列
            HStack(spacing: Space.xs) {  // 标题行
                Text("我的题目").font(AppFont.section)  // 标题
                Text("可删除，也可参与组卷").font(.system(size: 10.5))  // 说明（样板同文案）
                    .foregroundStyle(Color.textTertiary)  // 弱化色
                Spacer(minLength: 0)  // 撑开
            }  // 排列结束

            if items.isEmpty {  // 还没有自建题
                Text("还没录过题，点上面的「手动录题」加一道。")  // 空态文案
                    .font(AppFont.caption)  // 小字
                    .foregroundStyle(Color.textTertiary)  // 弱化色
                    .frame(maxWidth: .infinity, alignment: .leading)  // 左对齐
                    .padding(.vertical, Space.m)  // 上下留白
            } else {  // 有题
                ForEach(items) { q in  // 逐题
                    itemRow(q)  // 一行
                }  // 遍历结束
            }  // 分支结束
        }  // 排列结束
    }  // listSection 结束

    private func itemRow(_ q: Question) -> some View {  // 一道自建题
        Card {  // 白卡片
            VStack(alignment: .leading, spacing: 6) {  // 纵向排列
                HStack(spacing: 6) {  // 头部
                    Chip(text: q.type.title, tint: .appBrand)  // 题型
                    Spacer(minLength: 0)  // 撑开
                    Button {  // 删除
                        app.removeDiy(id: q.id)  // 从状态层删
                        show("已删除")  // 提示
                    } label: {  // 外观
                        Image(systemName: "trash")  // 垃圾桶
                            .font(.system(size: 13))  // 小图标
                            .foregroundStyle(Color.appErr)  // 红
                    }  // 外观结束
                    .buttonStyle(.plain)  // 不用默认高亮
                }  // 排列结束

                Text(q.stem)  // 题干
                    .font(AppFont.bodyStrong)  // 加粗
                    .fixedSize(horizontal: false, vertical: true)  // 允许换行

                Text(verbatim: "答案：\(q.answerText)")  // 正确答案
                    .font(.system(size: 11.5))  // 小字
                    .foregroundStyle(Color.appBrand)  // 品牌色

                if !q.explain.isEmpty {  // 有解析才显示
                    Text(q.explain)  // 解析
                        .font(.system(size: 11.5))  // 小字
                        .foregroundStyle(Color.textSecondary)  // 次要色
                        .fixedSize(horizontal: false, vertical: true)  // 允许换行
                }  // 分支结束
            }  // 排列结束
        }  // 卡片结束
    }  // itemRow 结束

    // MARK: - 保存                                                    // 分节：保存

    private func save() {  // 校验并保存
        let text = stem.trimmingCharacters(in: .whitespacesAndNewlines)  // 题干去空白
        guard !text.isEmpty else { show("题干不能为空"); return }  // 必须有题干

        let opts = options.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }  // 选项去空白
        guard opts.count >= 2, !opts.contains(where: \.isEmpty) else {  // 至少两项且不能空
            show("选项至少要两项，而且都不能空")  // 说清原因
            return  // 不保存
        }  // 分支结束

        let letters = answerText.uppercased().filter { $0.isLetter }  // 只留字母
        let indices = letters.compactMap { ch -> Int? in  // 字母转下标
            guard let ascii = ch.asciiValue else { return nil }  // 取不到就算了
            return Int(ascii - 65)  // A=0
        }  // 转换结束
        let valid = indices.filter { $0 >= 0 && $0 < opts.count }  // 只留下标合法的
        guard !valid.isEmpty, valid.count == Set(valid).count else {  // 至少一个且不能重复
            show("正确答案填 A、B 这样的字母，比如 AC")  // 提示格式
            return  // 不保存
        }  // 分支结束
        if type != .multi && valid.count > 1 {  // 单选判断题只能一个答案
            show("单选和判断题只能有一个正确答案")  // 说清
            return  // 不保存
        }  // 分支结束

        let q = Question(  // 组装题目
            id: "diy-\(UUID().uuidString)",  // 自建题唯一 id
            topic: "custom",  // 固定板块
            type: type,  // 题型
            stem: text,  // 题干
            options: opts,  // 选项
            answer: valid.sorted(),  // 答案下标
            explain: explain.trimmingCharacters(in: .whitespacesAndNewlines)  // 解析可空
        )  // 组装结束
        app.addDiy(q)  // 写进状态层
        resetForm()  // 清空表单
        withAnimation { showingForm = false }  // 收起
        show("已保存到我的题库")  // 提示
    }  // save 结束

    private func resetForm() {  // 清空表单
        stem = ""  // 清题干
        type = .single  // 回单选
        options = ["", ""]  // 两项空
        answerText = ""  // 清答案
        explain = ""  // 清解析
    }  // resetForm 结束

    private func show(_ text: String) {  // 弹提示
        withAnimation { hint = text }  // 淡入
        Task {  // 异步延时
            try? await Task.sleep(nanoseconds: 1_800_000_000)  // 1.8 秒
            withAnimation { hint = nil }  // 淡出
        }  // 任务结束
    }  // show 结束
}  // DiyBankView 结束
