//  ExamHallScene.swift —— 2D 考场舞台                                // 文件说明
//  照样板 page-room 的 .hall 结构：墙面 灯 白板 挂钟 窗 五位导师 会议桌 自视窗 字幕。
//  纯 SwiftUI 图形拼装，不含 3D；引擎与作答逻辑仍在 InterviewRoomView。 // 设计说明
//  导师排布「三前一后二」，与 S4.1 的考场设定一致。                    // 场景原则

import SwiftUI  // 界面框架

struct ExamHallScene: View {  // 2D 考场
    let roomName: String  // 面试间名
    let currentSpeaker: MentorRole  // 当前发言人
    let stepNumber: Int  // 第几问
    let totalSteps: Int  // 总问数
    let remainingSeconds: Int  // 剩余秒
    let question: String  // 当前问题
    let isBusy: Bool  // 是否正在请求

    private var timeText: String {  // 倒计时文本
        let s = max(0, remainingSeconds)  // 不为负
        return String(format: "%02d:%02d", s / 60, s % 60)  // 分比秒
    }  // timeText 结束

    var body: some View {  // 视图主体
        GeometryReader { geo in  // 取尺寸做相对定位
            let w = geo.size.width  // 宽
            let h = geo.size.height  // 高
            ZStack(alignment: .topLeading) {  // 叠放
                wall(w: w, h: h)  // 墙与地面
                lights(w: w, h: h)  // 顶部灯
                board(w: w, h: h)  // 白板
                clock(w: w, h: h)  // 挂钟
                window(w: w, h: h)  // 窗
                topStatus(w: w)  // 顶部状态
                stageBar(w: w, h: h)  // 环节进度
                mentors(w: w, h: h)  // 五位导师
                desk(w: w, h: h)  // 会议桌
                selfWindow(w: w, h: h)  // 自视窗
                subtitle(w: w, h: h)  // 字幕
            }  // 叠放结束
        }  // 几何结束
    }  // body 结束

    private func wall(w: CGFloat, h: CGFloat) -> some View {  // 墙与地面
        VStack(spacing: 0) {  // 上下两段
            LinearGradient(colors: [Color(hex: 0xF3EEE4), Color(hex: 0xE7DFD0)],  // 米色墙
                           startPoint: .top, endPoint: .bottom)  // 上到下
                .frame(height: h * 0.62)  // 墙高 62%
            LinearGradient(colors: [Color(hex: 0x4A3B2E), Color(hex: 0x2E241B)],  // 深色地面
                           startPoint: .top, endPoint: .bottom)  // 上到下
        }  // 排列结束
    }  // wall 结束

    private func lights(w: CGFloat, h: CGFloat) -> some View {  // 顶部三盏灯
        HStack(spacing: w * 0.06) {  // 三段
            ForEach(0..<3, id: \.self) { _ in  // 三盏
                Capsule().fill(LinearGradient(colors: [.white, Color(hex: 0xEEF6FF)],  // 灯管
                                              startPoint: .top, endPoint: .bottom))  // 上白下蓝
                    .frame(height: 4)  // 灯高
            }  // 遍历结束
        }  // 排列结束
        .padding(.horizontal, w * 0.08)  // 左右留白
        .padding(.top, 5)  // 贴顶
    }  // lights 结束

    private func board(w: CGFloat, h: CGFloat) -> some View {  // 白板
        VStack(alignment: .leading, spacing: 3) {  // 文字
            Text("2027 年硕士研究生复试")  // 主标题
                .font(.system(size: 11, weight: .bold))  // 小加粗
                .foregroundStyle(Color(hex: 0x2B2F3A))  // 深墨
            Text("专业能力与综合素质考核")  // 副标题
                .font(.system(size: 8))  // 极小
                .foregroundStyle(Color(hex: 0x8A94A6))  // 灰
        }  // 排列结束
        .padding(.horizontal, 8)  // 左右内边距
        .frame(width: w * 0.45, height: h * 0.16, alignment: .leading)  // 板尺寸
        .background(RoundedRectangle(cornerRadius: 5, style: .continuous)  // 白板底
            .fill(Color(hex: 0xF8FAFB))  // 近白
            .overlay(RoundedRectangle(cornerRadius: 5, style: .continuous)  // 描边
                .stroke(Color(hex: 0xD9DEE4), lineWidth: 1)))  // 浅灰边
        .position(x: w * 0.05 + w * 0.225, y: h * 0.10 + h * 0.08)  // 左上区域
    }  // board 结束

    private func clock(w: CGFloat, h: CGFloat) -> some View {  // 挂钟
        ZStack {  // 圆盘
            Circle().fill(.white)  // 白底
            Circle().stroke(Color(hex: 0xC9CFD6), lineWidth: 1)  // 灰边
            Image(systemName: "clock")  // 钟面图标
                .font(.system(size: 11))  // 小图标
                .foregroundStyle(Color(hex: 0x5B6069))  // 深灰
        }  // 叠放结束
        .frame(width: 26, height: 26)  // 尺寸
        .position(x: w * 0.90, y: h * 0.14)  // 右上
    }  // clock 结束

    private func window(w: CGFloat, h: CGFloat) -> some View {  // 窗
        VStack(spacing: 0) {  // 四格
            ForEach(0..<4, id: \.self) { i in  // 四行
                LinearGradient(colors: [Color(hex: 0xBFE0F2), Color(hex: 0xE9F6FD)],  // 天光
                               startPoint: .top, endPoint: .bottom)  // 上到下
                    .overlay(Rectangle().frame(height: 1).foregroundStyle(.white.opacity(0.8)),  // 分隔线
                             alignment: .bottom)  // 贴底
            }  // 遍历结束
        }  // 排列结束
        .frame(width: w * 0.12, height: h * 0.32)  // 窗尺寸
        .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))  // 圆角
        .position(x: w * 0.90, y: h * 0.47)  // 右侧
    }  // window 结束

    private func topStatus(w: CGFloat) -> some View {  // 顶部状态
        HStack(spacing: 6) {  // 横排
            HStack(spacing: 3) {  // 录像中
                Circle().fill(Color(hex: 0xE24B4A)).frame(width: 6, height: 6)  // 红点
                Text("录像中").font(.system(size: 9)).foregroundStyle(Color(hex: 0x8A94A6))  // 文字
            }  // 结束
            Spacer()  // 撑开
            Text(roomName)  // 面试间名
                .font(.system(size: 9))  // 小字
                .foregroundStyle(Color(hex: 0x5B6069))  // 深灰
                .padding(.horizontal, 7).padding(.vertical, 2)  // 内边距
                .background(Capsule().fill(.white.opacity(0.78)))  // 白胶囊
            Spacer()  // 撑开
            Text(verbatim: timeText)  // 倒计时
                .font(.system(size: 8.5)).monospacedDigit()  // 等宽
                .foregroundStyle(Color(hex: 0x5B6069))  // 深灰
                .padding(.horizontal, 6).padding(.vertical, 2)  // 内边距
                .background(Capsule().fill(.white.opacity(0.78)))  // 白胶囊
        }  // 排列结束
        .padding(.horizontal, 10)  // 左右留白
        .padding(.top, 4)  // 贴顶
    }  // topStatus 结束

    private func stageBar(w: CGFloat, h: CGFloat) -> some View {  // 环节进度
        let n = max(totalSteps, 1)  // 段数
        return HStack(spacing: 3) {  // 横排
            ForEach(0..<n, id: \.self) { i in  // 逐段
                Capsule()  // 细条
                    .fill(i < stepNumber ? AnyShapeStyle(Color(hex: 0x2B54E8)) : AnyShapeStyle(Color(hex: 0x6E7A91).opacity(0.2)))  // 已答蓝
                    .frame(height: 3)  // 细
            }  // 遍历结束
        }  // 排列结束
        .padding(.horizontal, 9)  // 左右留白
        .position(x: w / 2, y: h * 0.085)  // 顶部下方
    }  // stageBar 结束

    private func mentors(w: CGFloat, h: CGFloat) -> some View {  // 五位导师
        let seated = MentorRole.seated  // 五位
        let front = Array(seated.prefix(3))  // 前排三个
        let back = Array(seated.dropFirst(3))  // 后排两个
        let frontX: [CGFloat] = [0.20, 0.50, 0.80]  // 前排横位
        let backX: [CGFloat] = [0.36, 0.64]  // 后排横位
        return ZStack {  // 叠放
            ForEach(Array(front.enumerated()), id: \.element.id) { idx, role in  // 前排
                mentorAvatar(role: role, size: 46)  // 头像
                    .position(x: w * frontX[idx], y: h * 0.45)  // 定位
            }  // 遍历结束
            ForEach(Array(back.enumerated()), id: \.element.id) { idx, role in  // 后排
                mentorAvatar(role: role, size: 40)  // 头像
                    .position(x: w * backX[idx], y: h * 0.29)  // 定位
            }  // 遍历结束
        }  // 叠放结束
    }  // mentors 结束

    private func mentorAvatar(role: MentorRole, size: CGFloat) -> some View {  // 单个导师头像
        let active = role == currentSpeaker  // 是否在发言
        return VStack(spacing: 3) {  // 纵向
            ZStack {  // 头像
                Circle().fill(active ? Color(hex: 0x2B54E8) : Color(hex: 0xE7EBF2))  // 底色
                    .frame(width: size, height: size)  // 尺寸
                Image(systemName: "person.fill")  // 人形
                    .font(.system(size: size * 0.42))  // 图标比例
                    .foregroundStyle(active ? .white : Color(hex: 0x8A94A6))  // 字色
                if active {  // 发言中加个环
                    Circle().stroke(Color(hex: 0x2B54E8).opacity(0.35), lineWidth: 3)  // 外环
                        .frame(width: size + 8, height: size + 8)  // 稍大
                }  // 分支结束
            }  // 叠放结束
            Text(role.title)  // 角色名
                .font(.system(size: 8.5, weight: active ? .semibold : .regular))  // 小字
                .foregroundStyle(active ? Color(hex: 0x2B54E8) : Color(hex: 0x8A94A6))  // 高亮
                .lineLimit(1)  // 单行
        }  // 排列结束
        .accessibilityElement(children: .ignore)  // 合并朗读
        .accessibilityLabel("导师 \(role.title)\(active ? "，正在提问" : "")")  // 无障碍
    }  // mentorAvatar 结束

    private func desk(w: CGFloat, h: CGFloat) -> some View {  // 会议桌
        VStack(spacing: 0) {  // 纵向
            Rectangle().fill(Color.white.opacity(0.17)).frame(height: h * 0.05)  // 桌面反光
            HStack {  // 桌面物件
                deskItem(kind: .water)  // 水杯
                Spacer()  // 撑开
                deskItem(kind: .folder)  // 文件夹
                Spacer()  // 撑开
                deskItem(kind: .cup)  // 杯子
                Spacer()  // 撑开
                deskItem(kind: .mic)  // 麦克风
                Spacer()  // 撑开
                deskItem(kind: .cup)  // 杯子
                Spacer()  // 撑开
                deskItem(kind: .folder)  // 文件夹
                Spacer()  // 撑开
                deskItem(kind: .water)  // 水杯
            }  // 排列结束
            .padding(.horizontal, w * 0.06)  // 左右留白
            .padding(.top, h * 0.01)  // 贴桌面
            Spacer(minLength: 0)  // 余下留空
        }  // 排列结束
        .frame(width: w, height: h * 0.44)  // 桌面高度
        .background(LinearGradient(colors: [Color(hex: 0x6B4E36), Color(hex: 0x4A3524)],  // 木色
                                   startPoint: .top, endPoint: .bottom))  // 上到下
        .position(x: w / 2, y: h * 0.56 + h * 0.22)  // 下半个
        .allowsHitTesting(false)  // 不挡点击
    }  // desk 结束

    private enum DeskKind { case water, folder, cup, mic }  // 桌面物件种类

    @ViewBuilder  // 多分支返回
    private func deskItem(kind: DeskKind) -> some View {  // 桌面小物
        switch kind {  // 按种类
        case .water:  // 水杯
            RoundedRectangle(cornerRadius: 3, style: .continuous).fill(Color(hex: 0xBFE3F7)).frame(width: 9, height: 20)  // 蓝瓶
        case .folder:  // 文件夹
            RoundedRectangle(cornerRadius: 2, style: .continuous).fill(Color(hex: 0xD9CBA8)).frame(width: 34, height: 12)  // 米黄
        case .cup:  // 杯子
            Circle().fill(Color(hex: 0xE9ECEF)).frame(width: 12, height: 12)  // 白杯
        case .mic:  // 麦克风
            RoundedRectangle(cornerRadius: 2, style: .continuous).fill(Color(hex: 0x2B2F3A)).frame(width: 3, height: 20)  // 黑麦
        }  // 分支结束
    }  // deskItem 结束

    private func selfWindow(w: CGFloat, h: CGFloat) -> some View {  // 自视窗
        VStack(spacing: 2) {  // 纵向
            Image(systemName: "person.crop.circle.badge.xmark")  // 不露脸
                .font(.system(size: 18))  // 图标
                .foregroundStyle(.white.opacity(0.9))  // 白
            Text("你 · 不露脸")  // 说明
                .font(.system(size: 7.5))  // 极小
                .foregroundStyle(.white.opacity(0.85))  // 白
        }  // 排列结束
        .frame(width: 52, height: 54)  // 尺寸
        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color(hex: 0x1B1E26).opacity(0.9)))  // 深底
        .position(x: w * 0.85, y: h * 0.70)  // 右下
        .accessibilityLabel("考生自视窗，不露脸")  // 无障碍
    }  // selfWindow 结束

    private func subtitle(w: CGFloat, h: CGFloat) -> some View {  // 提问字幕
        VStack(alignment: .leading, spacing: 2) {  // 纵向
            HStack(spacing: 4) {  // 提问人
                Text(currentSpeaker.title)  // 角色名
                    .font(.system(size: 9, weight: .semibold))  // 小加粗
                    .foregroundStyle(Color(hex: 0x9FB4FF))  // 淡蓝
                if isBusy {  // 正在请求
                    ProgressView().scaleEffect(0.35).tint(.white)  // 小转圈
                }  // 分支结束
            }  // 排列结束
            Text(question.isEmpty ? "正在准备问题…" : question)  // 问题
                .font(.system(size: 10.5))  // 小字
                .foregroundStyle(Color(hex: 0xF2F4FA))  // 近白
                .lineLimit(3)  // 最多三行
                .fixedSize(horizontal: false, vertical: true)  // 允许换行
        }  // 排列结束
        .frame(maxWidth: .infinity, alignment: .leading)  // 撑满左对齐
        .padding(.horizontal, 9).padding(.vertical, 6)  // 内边距
        .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(Color(hex: 0x10131A).opacity(0.72)))  // 深底
        .padding(.horizontal, 10)  // 外边距
        .position(x: w / 2, y: h * 0.90)  // 底部
    }  // subtitle 结束
}  // ExamHallScene 结束
