//  CommunityView.swift —— 研友论坛（样板 page-community）              // 文件说明
//  结构逐块照样板：分类筛选 → AI 学伴入口 → 帖子流 → 右下角发帖按钮      // 来源说明
//  数据全在本地（种子帖 + 我发的帖），不连任何接口，离线也能用              // 数据说明

import SwiftUI  // 界面框架

struct CommunityView: View {  // 研友论坛
    @Environment(AppState.self) private var app  // 全局状态
    @State private var filter: PostCategory?  // 当前分类，nil 表示「推荐」（全部）
    @State private var composing = false  // 是否在发帖
    @State private var askingAI = false  // 是否弹了 AI 学伴

    private var posts: [CommunityPost] {  // 当前筛选下的帖子
        let all = app.communityAllPosts  // 我的在前，种子在后
        guard let filter else { return all }  // 推荐就是全部
        return all.filter { $0.cat == filter }  // 按分类过滤
    }  // posts 结束

    var body: some View {  // 视图主体
        ScrollView {  // 可滚动
            VStack(alignment: .leading, spacing: Space.s) {  // 纵向排列（样板 gap 10 左右）
                filterChips  // 分类筛选条
                aiEntry  // AI 学伴入口
                postList  // 帖子流
            }  // 排列结束
            .padding(.horizontal, Metrics.pagePadding)  // 左右边距
            .padding(.bottom, 96)  // 底部留白：悬浮 TabBar 不占安全区，必须手动让开
        }  // 滚动结束
        .background(Color.appBG)  // 底色
        .navigationTitle("研友论坛")  // 标题（样板 app.js 里的 page 名）
        .navigationBarTitleDisplayMode(.inline)  // 内联标题，别占太多高度
        .overlay(alignment: .bottomTrailing) { fab }  // 右下角悬浮发帖按钮
        .sheet(isPresented: $composing) {  // 发帖弹层
            ComposeSheet { text, category in  // 收到发布回调
                app.publishCommunityPost(text: text, category: category)  // 交给状态层写入
            }  // 弹层结束
        }  // sheet 结束
        .sheet(isPresented: $askingAI) {  // AI 学伴弹层（样板点开是 AI 面板）
            NavigationStack {  // 套导航栈才有标题栏与关闭键
                ScrollView {  // 可滚动
                    CoachCard()  // 复用首页那张学伴卡，逻辑与限流完全一致
                        .padding(Metrics.pagePadding)  // 内边距
                }  // 滚动结束
                .background(Color.appBG)  // 底色
                .navigationTitle("AI 学伴")  // 标题（样板原话）
                .navigationBarTitleDisplayMode(.inline)  // 内联
                .toolbar {  // 顶部工具
                    ToolbarItem(placement: .topBarTrailing) {  // 右上角
                        Button("关闭") { askingAI = false }  // 关掉弹层
                    }  // 工具项结束
                }  // 工具栏结束
            }  // 栈结束
        }  // sheet 结束
    }  // body 结束

    // MARK: - 分类筛选                                                  // 分节：筛选

    private var filterChips: some View {  // 四个胶囊（照样板 .topic-chips）
        ScrollView(.horizontal, showsIndicators: false) {  // 横向滚动
            HStack(spacing: Space.xs) {  // 横向排列
                chip(title: "推荐", value: nil)  // 推荐＝全部
                ForEach(PostCategory.allCases, id: \.id) { cat in  // 三个分类
                    chip(title: cat.title, value: cat)  // 单个分类
                }  // 遍历结束
            }  // 排列结束
            .padding(.vertical, 2)  // 上下留一点，避免投影被裁
        }  // 滚动结束
    }  // filterChips 结束

    private func chip(title: String, value: PostCategory?) -> some View {  // 单个胶囊
        let active = filter == value  // 是不是选中态
        return Button {  // 点击切换
            filter = value  // 写入筛选
        } label: {  // 外观
            Text(title)  // 文案
                .font(.system(size: 12.5, weight: active ? .semibold : .regular))  // 选中加粗（样板 600）
                .foregroundStyle(active ? Color.white : Color.textSecondary)  // 选中白字
                .padding(.horizontal, 13)  // 左右内边距（样板 13）
                .frame(height: 30)  // 高度 30（样板同）
                .background(  // 底色
                    Capsule().fill(active ? Color.textPrimary : Color.appCard)  // 选中深底，否则白底
                )  // 背景结束
        }  // 按钮结束
        .buttonStyle(.plain)  // 去掉系统高亮
    }  // chip 结束

    // MARK: - AI 学伴入口                                               // 分节：AI 入口

    private var aiEntry: some View {  // 一行细长卡片（样板 .ai-card.slim）
        Button {  // 点开 AI
            askingAI = true  // 弹层
        } label: {  // 外观
            HStack(spacing: Space.m) {  // 横向排列
                ZStack {  // 叠放小球
                    Circle().fill(Color.appViolet.opacity(0.12)).frame(width: 26, height: 26)  // 淡紫圆底
                    Circle().fill(Color.appViolet).frame(width: 9, height: 9)  // 中心紫点（样板 .ai-orb i）
                }  // 叠放结束
                VStack(alignment: .leading, spacing: 1) {  // 文字区
                    Text("问 AI 学伴").font(.system(size: 13, weight: .semibold))  // 主标题（样板原话）
                    Text("答疑、改自我介绍、模拟追问")  // 副标题（样板原话）
                        .font(.system(size: 10.5))  // 小字
                        .foregroundStyle(Color.textTertiary)  // 弱化色
                }  // 文字区结束
                Spacer()  // 撑开
                Image(systemName: "chevron.right")  // 右箭头（样板 .chev）
                    .font(.system(size: 12, weight: .semibold))  // 小箭头
                    .foregroundStyle(Color.textTertiary)  // 弱化色
            }  // 排列结束
            .padding(.horizontal, Space.m)  // 左右内边距
            .padding(.vertical, 10)  // 上下内边距
            .background(  // 底色
                RoundedRectangle(cornerRadius: 14, style: .continuous)  // 圆角
                    .fill(Color.appCard)  // 白底
            )  // 背景结束
        }  // 按钮结束
        .buttonStyle(.plain)  // 去掉系统高亮
    }  // aiEntry 结束

    // MARK: - 帖子流                                                    // 分节：帖子流

    private var postList: some View {  // 帖子列表
        VStack(spacing: Space.s) {  // 纵向排列
            if posts.isEmpty {  // 该分类没帖
                Text("这个分类还没有帖子")  // 样板原文
                    .font(AppFont.caption)  // 小字
                    .foregroundStyle(Color.textTertiary)  // 弱化色
                    .frame(maxWidth: .infinity)  // 撑满
                    .padding(.vertical, Space.xxl)  // 上下留白
            } else {  // 有帖子
                ForEach(posts) { post in  // 逐条
                    NavigationLink {  // 点进详情
                        PostDetailView(post: post)  // 帖子详情页
                    } label: {  // 外观
                        postRow(post)  // 单条卡片
                    }  // 链接结束
                    .buttonStyle(.plain)  // 去掉系统高亮
                }  // 遍历结束
            }  // 分支结束
        }  // 排列结束
    }  // postList 结束

    private func postRow(_ post: CommunityPost) -> some View {  // 单条帖子（样板 .post）
        VStack(alignment: .leading, spacing: 0) {  // 纵向排列
            HStack(spacing: 9) {  // 头部行（样板 gap 9）
                avatar(post)  // 头像
                VStack(alignment: .leading, spacing: 1) {  // 昵称与时间
                    Text(post.author + (post.isMine ? " · 我" : ""))  // 昵称，自己发的加后缀（样板同）
                        .font(.system(size: 12.5, weight: .semibold))  // 昵称加粗
                        .foregroundStyle(Color.textPrimary)  // 主色
                    Text(post.time)  // 时间
                        .font(.system(size: 10))  // 小字
                        .foregroundStyle(Color.textTertiary)  // 弱化色
                }  // 昵称区结束
                Spacer()  // 撑开
                Text(post.cat.title)  // 分类角标
                    .font(.system(size: 9.5, weight: .semibold))  // 很小的字
                    .foregroundStyle(Color.appBrand)  // 品牌蓝
                    .padding(.horizontal, 7)  // 左右 7
                    .padding(.vertical, 2)  // 上下 2
                    .background(  // 底
                        RoundedRectangle(cornerRadius: 6, style: .continuous)  // 小圆角
                            .fill(Color.appBrand.opacity(0.1))  // 淡蓝
                    )  // 背景结束
            }  // 头部行结束
            .padding(.bottom, 8)  // 与正文间距（样板 8）

            Text(post.text)  // 正文（保留换行）
                .font(.system(size: 13))  // 13 号（样板同）
                .lineSpacing(4)  // 行高（样板 1.65 倍约等于此）
                .foregroundStyle(Color.textPrimary)  // 主色
                .frame(maxWidth: .infinity, alignment: .leading)  // 左对齐撑满

            HStack(spacing: Space.l) {  // 底部互动行
                Label("\(app.communityLikeCount(post))", systemImage:  // 点赞数与图标
                      app.communityLiked(post.id) ? "heart.fill" : "heart")  // 点过就实心
                    .font(.system(size: 11.5))  // 小字
                    .foregroundStyle(app.communityLiked(post.id) ? Color.appErr : Color.textSecondary)  // 点过变红（样板 .liked）
                Label("\(post.comments.count)", systemImage: "bubble.left")  // 评论数
                    .font(.system(size: 11.5))  // 小字
                    .foregroundStyle(Color.textSecondary)  // 次要色
            }  // 互动行结束
            .padding(.top, 9)  // 上边距（样板 9）
            .frame(maxWidth: .infinity, alignment: .leading)  // 左对齐
            .overlay(alignment: .top) {  // 顶部细线（样板 border-top）
                Rectangle().fill(Color.separator).frame(height: 0.5)  // 半像素线
            }  // 覆盖层结束
            .padding(.top, Space.s)  // 与正文拉开
        }  // 纵向排列结束
        .padding(13)  // 卡片内边距（样板 13）
        .background(  // 卡片底
            RoundedRectangle(cornerRadius: 15, style: .continuous)  // 圆角 15（样板同）
                .fill(Color.appCard)  // 白底
        )  // 背景结束
    }  // postRow 结束

    private func avatar(_ post: CommunityPost) -> some View {  // 圆形头像
        ZStack {  // 叠放
            Circle().fill(  // 圆形渐变底（样板每个作者一套）
                LinearGradient(colors: [Color(hex: post.topHex), Color(hex: post.bottomHex)],  // 两端取模型里的色
                               startPoint: .topLeading, endPoint: .bottomTrailing)  // 左上到右下
            )  // 填充结束
            Text(post.firstChar)  // 首字
                .font(.system(size: 12, weight: .bold))  // 小粗字（样板 700 / 12）
                .foregroundStyle(Color.white)  // 白字
        }  // 叠放结束
        .frame(width: 32, height: 32)  // 32 直径（样板同）
    }  // avatar 结束

    // MARK: - 发帖按钮                                                  // 分节：发帖按钮

    private var fab: some View {  // 右下角圆钮（样板 .fab）
        Button {  // 点击发帖
            composing = true  // 弹出发帖层
        } label: {  // 外观
            ZStack {  // 叠放
                Circle().fill(Color.brandGradient)  // 品牌渐变底
                Image(systemName: "plus")  // 加号
                    .font(.system(size: 20, weight: .semibold))  // 图标大小
                    .foregroundStyle(Color.white)  // 白图标
            }  // 叠放结束
            .frame(width: 50, height: 50)  // 50 直径（样板同）
            .shadow(color: Color.appBrand.opacity(0.35), radius: 13, x: 0, y: 8)  // 蓝色投影（样板同感觉）
        }  // 按钮结束
        .buttonStyle(.plain)  // 去掉系统高亮
        .accessibilityIdentifier("compose-fab")  // 给 UI 测试一个稳定的抓手（纯加号图标没有可读文案）
        .padding(.trailing, 18)  // 距右 18（样板同）
        .padding(.bottom, 118)  // 抬到悬浮 TabBar 之上（样板是 22，iOS 要让开胶囊）
    }  // fab 结束
}  // CommunityView 结束

// MARK: - 发帖弹层                                                      // 分节：发帖

struct ComposeSheet: View {  // 发帖弹层（样板 #composeSheet）
    @Environment(\.dismiss) private var dismiss  // 关闭用
    @State private var text = ""  // 正文
    @State private var category: PostCategory = .exp  // 分类，样板默认经验
    @State private var errorText: String?  // 错误提示
    let onPublish: (String, PostCategory) -> Void  // 发布回调

    private let limit = 800  // 最长字数，防止塞爆本地快照

    var body: some View {  // 视图主体
        NavigationStack {  // 套导航栈
            ScrollView {  // 可滚动，键盘弹起也能看全
                VStack(alignment: .leading, spacing: Space.m) {  // 纵向排列
                    Text("选个分类")  // 小标题
                        .font(AppFont.captionStrong)  // 加粗小字
                        .foregroundStyle(Color.textSecondary)  // 次要色
                    HStack(spacing: Space.xs) {  // 三个分类
                        ForEach(PostCategory.allCases, id: \.id) { cat in  // 遍历
                            Button {  // 点选
                                category = cat  // 记录
                            } label: {  // 外观
                                Text(cat.title)  // 文案
                                    .font(.system(size: 12.5, weight: category == cat ? .semibold : .regular))  // 选中加粗
                                    .foregroundStyle(category == cat ? Color.white : Color.textSecondary)  // 选中白字
                                    .padding(.horizontal, 13)  // 左右内边距
                                    .frame(height: 30)  // 高 30
                                    .background(Capsule().fill(category == cat ? Color.textPrimary : Color.appCard))  // 选中深底
                            }  // 按钮结束
                            .buttonStyle(.plain)  // 去掉系统高亮
                        }  // 遍历结束
                    }  // 排列结束

                    TextEditor(text: $text)  // 正文输入
                        .font(.system(size: 14))  // 字号
                        .scrollContentBackground(.hidden)  // 去掉系统底色
                        .frame(minHeight: 180)  // 最小高度
                        .padding(Space.xs)  // 内边距
                        .background(  // 底
                            RoundedRectangle(cornerRadius: 14, style: .continuous)  // 圆角
                                .fill(Color.appCard)  // 白底
                        )  // 背景结束
                        .overlay(alignment: .topLeading) {  // 占位文字
                            if text.isEmpty {  // 空才显示
                                Text("说点什么…")  // 占位（样板 placeholder 同义）
                                    .font(.system(size: 14))  // 同字号
                                    .foregroundStyle(Color.textTertiary)  // 弱化色
                                    .padding(.horizontal, Space.m)  // 对齐输入区
                                    .padding(.vertical, Space.l)  // 对齐输入区
                                    .allowsHitTesting(false)  // 别挡住点击
                            }  // 分支结束
                        }  // 覆盖层结束
                        .onChange(of: text) { _, newValue in  // 字数超了就截断
                            if newValue.count > limit { text = String(newValue.prefix(limit)) }  // 截到上限
                        }  // 变更回调结束

                    HStack {  // 字数与错误
                        Text("\(text.count) / \(limit)")  // 已写字数
                            .font(.system(size: 11))  // 小字
                            .foregroundStyle(Color.textTertiary)  // 弱化色
                        Spacer()  // 撑开
                        if let errorText {  // 有错误就显示
                            Text(errorText)  // 提示
                                .font(.system(size: 11))  // 小字
                                .foregroundStyle(Color.appErr)  // 红色
                        }  // 分支结束
                    }  // 排列结束
                }  // 排列结束
                .padding(Metrics.pagePadding)  // 内边距
            }  // 滚动结束
            .background(Color.appBG)  // 底色
            .navigationTitle("发布")  // 标题（样板 composeTitle 同义）
            .navigationBarTitleDisplayMode(.inline)  // 内联
            .toolbar {  // 顶部工具
                ToolbarItem(placement: .topBarLeading) {  // 左取消
                    Button("取消") { dismiss() }  // 关掉
                }  // 工具项结束
                ToolbarItem(placement: .topBarTrailing) {  // 右发布
                    Button("发布") { publish() }  // 提交
                        .fontWeight(.semibold)  // 加粗
                }  // 工具项结束
            }  // 工具栏结束
        }  // 栈结束
    }  // body 结束

    private func publish() {  // 提交发布
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)  // 去首尾空白
        guard trimmed.count >= 5 else {  // 样板规则：不足 5 字不发
            errorText = "再多写几个字吧"  // 样板原话
            return  // 停在这
        }  // 分支结束
        onPublish(trimmed, category)  // 交给状态层
        dismiss()  // 关掉弹层
    }  // publish 结束
}  // ComposeSheet 结束
