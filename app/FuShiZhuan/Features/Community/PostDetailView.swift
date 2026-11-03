//  PostDetailView.swift —— 帖子详情（样板 page-post）                  // 文件说明
//  结构逐块照样板：#postDetail 卡片 → 评论 N 分组 → 底部固定输入条        // 来源说明

import SwiftUI  // 界面框架

struct PostDetailView: View {  // 帖子详情
    @Environment(AppState.self) private var app  // 全局状态
    @State private var draft = ""  // 评论草稿

    let post: CommunityPost  // 进来时那一条（只用来查 id）

    private var current: CommunityPost {  // 取最新的这一条（点赞、评论后要重算）
        app.communityAllPosts.first { $0.id == post.id } ?? post  // 找不到就退回传入值
    }  // current 结束

    var body: some View {  // 视图主体
        ScrollView {  // 可滚动
            VStack(alignment: .leading, spacing: Space.m) {  // 纵向排列
                detailCard  // 帖子本体
                commentSection  // 评论分组
            }  // 排列结束
            .padding(.horizontal, Metrics.pagePadding)  // 左右边距
            .padding(.bottom, Space.xl)  // 底部留白（输入条用 safeAreaInset 让位）
        }  // 滚动结束
        .background(Color.appBG)  // 底色
        .navigationTitle("帖子详情")  // 标题（样板 app.js 里的 page 名）
        .navigationBarTitleDisplayMode(.inline)  // 内联
        .safeAreaInset(edge: .bottom) { commentBar }  // 底部固定输入条（样板 .comment-bar 是 sticky）
    }  // body 结束

    // MARK: - 帖子本体                                                  // 分节：本体

    private var detailCard: some View {  // 帖子卡片（样板 .post-detail）
        VStack(alignment: .leading, spacing: 0) {  // 纵向排列
            HStack(spacing: 9) {  // 头部行
                ZStack {  // 头像
                    Circle().fill(  // 渐变底
                        LinearGradient(colors: [Color(hex: current.topHex), Color(hex: current.bottomHex)],  // 两端色
                                       startPoint: .topLeading, endPoint: .bottomTrailing)  // 左上到右下
                    )  // 填充结束
                    Text(current.firstChar)  // 首字
                        .font(.system(size: 12, weight: .bold))  // 小粗字
                        .foregroundStyle(Color.white)  // 白字
                }  // 叠放结束
                .frame(width: 32, height: 32)  // 32 直径

                VStack(alignment: .leading, spacing: 1) {  // 昵称与时间
                    Text(current.author + (current.isMine ? " · 我" : ""))  // 昵称
                        .font(.system(size: 12.5, weight: .semibold))  // 加粗
                    Text(current.time)  // 时间
                        .font(.system(size: 10))  // 小字
                        .foregroundStyle(Color.textTertiary)  // 弱化色
                }  // 昵称区结束
                Spacer()  // 撑开
                Text(current.cat.title)  // 分类角标
                    .font(.system(size: 9.5, weight: .semibold))  // 很小的字
                    .foregroundStyle(Color.appBrand)  // 品牌蓝
                    .padding(.horizontal, 7)  // 左右 7
                    .padding(.vertical, 2)  // 上下 2
                    .background(  // 底
                        RoundedRectangle(cornerRadius: 6, style: .continuous).fill(Color.appBrand.opacity(0.1))  // 淡蓝小圆角
                    )  // 背景结束
            }  // 头部行结束
            .padding(.bottom, 8)  // 与正文间距

            Text(current.text)  // 正文
                .font(.system(size: 13))  // 13 号
                .lineSpacing(4)  // 行高
                .frame(maxWidth: .infinity, alignment: .leading)  // 左对齐撑满

            Button {  // 点赞按钮（样板 #detailLike）
                app.toggleCommunityLike(current.id)  // 交给状态层
            } label: {  // 外观
                Label("\(app.communityLikeCount(current))",  // 点赞数
                      systemImage: app.communityLiked(current.id) ? "heart.fill" : "heart")  // 点过就实心
                    .font(.system(size: 11.5))  // 小字
                    .foregroundStyle(app.communityLiked(current.id) ? Color.appErr : Color.textSecondary)  // 点过变红
            }  // 按钮结束
            .buttonStyle(.plain)  // 去掉系统高亮
            .padding(.top, Space.s)  // 与正文拉开
        }  // 纵向排列结束
        .padding(14)  // 卡片内边距（样板 14）
        .background(  // 卡片底
            RoundedRectangle(cornerRadius: 15, style: .continuous).fill(Color.appCard)  // 白底圆角
        )  // 背景结束
    }  // detailCard 结束

    // MARK: - 评论区                                                    // 分节：评论

    private var commentSection: some View {  // 评论分组（样板 .group）
        VStack(alignment: .leading, spacing: Space.s) {  // 纵向排列
            HStack(spacing: Space.xxs) {  // 分组标题行
                Text("评论").font(AppFont.section)  // 标题
                Text("\(current.comments.count)")  // 数量（样板 #commentCount）
                    .font(AppFont.caption)  // 小字
                    .foregroundStyle(Color.textTertiary)  // 弱化色
            }  // 标题行结束

            if current.comments.isEmpty {  // 没评论
                Text("还没有评论，来说第一句")  // 样板原文
                    .font(AppFont.caption)  // 小字
                    .foregroundStyle(Color.textTertiary)  // 弱化色
                    .frame(maxWidth: .infinity)  // 撑满
                    .padding(.vertical, Space.xl)  // 上下留白
            } else {  // 有评论
                VStack(spacing: 9) {  // 纵向排列（样板 gap 9）
                    ForEach(current.comments) { comment in  // 逐条
                        commentRow(comment)  // 单条
                    }  // 遍历结束
                }  // 排列结束
            }  // 分支结束
        }  // 排列结束
    }  // commentSection 结束

    private func commentRow(_ comment: PostComment) -> some View {  // 单条评论（样板 .comment）
        HStack(alignment: .top, spacing: 9) {  // 横向排列
            ZStack {  // 灰头像
                Circle().fill(Color(hex: 0x8E8E93))  // 灰底（样板评论头像统一灰）
                Text(String(comment.author.prefix(1)))  // 首字
                    .font(.system(size: 10, weight: .bold))  // 更小的字
                    .foregroundStyle(Color.white)  // 白字
            }  // 叠放结束
            .frame(width: 26, height: 26)  // 26 直径（评论头像比帖子小）

            VStack(alignment: .leading, spacing: 2) {  // 文字区
                Text(comment.author)  // 昵称
                    .font(.system(size: 12, weight: .semibold))  // 加粗
                Text(comment.text)  // 正文
                    .font(.system(size: 12.5))  // 12.5 号
                    .lineSpacing(3)  // 行高
                    .frame(maxWidth: .infinity, alignment: .leading)  // 左对齐
                Text(comment.time)  // 时间
                    .font(.system(size: 10))  // 小字
                    .foregroundStyle(Color.textTertiary)  // 弱化色
            }  // 文字区结束
        }  // 排列结束
        .padding(11)  // 内边距（样板 11）
        .background(  // 底
            RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.appCard)  // 白底圆角
        )  // 背景结束
    }  // commentRow 结束

    // MARK: - 底部输入条                                                // 分节：输入条

    private var commentBar: some View {  // 输入条（样板 .comment-bar）
        HStack(spacing: Space.xs) {  // 横向排列
            TextField("说点什么…", text: $draft)  // 输入框（样板 placeholder 原文）
                .font(.system(size: 13))  // 字号
                .padding(.horizontal, 14)  // 左右内边距
                .frame(height: 38)  // 高 38（样板同）
                .background(  // 底
                    Capsule().fill(Color.appCard)  // 白胶囊
                )  // 背景结束
                .overlay(  // 描边
                    Capsule().stroke(Color.separator, lineWidth: 1)  // 细边（样板同）
                )  // 覆盖层结束

            Button {  // 发送
                if app.addCommunityComment(draft, to: current) { draft = "" }  // 空内容会被状态层拒掉
            } label: {  // 外观
                ZStack {  // 叠放
                    Circle().fill(Color.appBrand)  // 品牌蓝圆底
                    Image(systemName: "arrow.up")  // 上箭头（样板 send-btn 图标）
                        .font(.system(size: 15, weight: .semibold))  // 图标大小
                        .foregroundStyle(Color.white)  // 白图标
                }  // 叠放结束
                .frame(width: 34, height: 34)  // 34 直径（样板同）
            }  // 按钮结束
            .buttonStyle(.plain)  // 去掉系统高亮
            .opacity(draft.trimmingCharacters(in: .whitespaces).isEmpty ? 0.45 : 1)  // 空内容变淡提示（不用 disabled，系统还会再压一层）
        }  // 排列结束
        .padding(.horizontal, Metrics.pagePadding)  // 左右边距
        .padding(.top, Space.s)  // 上边距
        .padding(.bottom, 96)  // 让开悬浮 TabBar（样板是贴底，iOS 要抬起来）
        .background(  // 渐变底，滚动内容不会糊到输入条上（样板同）
            LinearGradient(colors: [Color.appBG.opacity(0), Color.appBG],  // 上透下实
                           startPoint: .top, endPoint: .bottom)  // 从上到下
        )  // 背景结束
    }  // commentBar 结束
}  // PostDetailView 结束
