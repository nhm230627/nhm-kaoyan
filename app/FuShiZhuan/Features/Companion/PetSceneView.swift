//  PetSceneView.swift —— 伙伴的 3D 形象（程序化几何体，不用外部资产）      // 文件说明
//  为什么不用 .usdz：本机是 Windows，做不了也验不了 3D 资产；先用代码搭几何体，换资产只改建模函数
//  约定：整只宠物缩到 0.67（用户要求小三分之一），硕士帽流苏 #ef3b30、金环 #ffc93c
//  注意：本文件没有在 Xcode 里编译过，API 名称按 iOS 17 RealityKit 写，上 Mac 后需逐行核对

import RealityKit                                                 // 3D 引擎
import SwiftUI                                                    // 界面框架
import UIKit                                                      // UIColor

// MARK: - 颜色与尺寸                                                    // 分节：常量

enum PetPalette {                                                 // 配色
    static let body = UIColor(red: 0.56, green: 0.83, blue: 0.96, alpha: 1)   // 身体：浅蓝 #8FD3F4
    static let belly = UIColor(red: 0.91, green: 0.97, blue: 1.00, alpha: 1)  // 肚皮：近白 #E8F7FF
    static let eye = UIColor(red: 0.17, green: 0.18, blue: 0.21, alpha: 1)    // 眼睛：墨黑 #2B2B33
    static let cap = UIColor(red: 0.14, green: 0.15, blue: 0.17, alpha: 1)    // 学士帽：#23252B
    static let ring = UIColor(red: 1.00, green: 0.79, blue: 0.24, alpha: 1)   // 金环：#FFC93C
    static let tassel = UIColor(red: 0.94, green: 0.23, blue: 0.19, alpha: 1) // 流苏：#EF3B30
    static let ground = UIColor(red: 0.85, green: 0.87, blue: 0.91, alpha: 1) // 地台：#D9DEE8
}                                                                 // PetPalette 结束

enum PetMetrics {                                                 // 尺寸
    static let petScale: Float = 0.67                             // 整体缩放：样板的三分之二
    static let bodyRadius: Float = 0.28                           // 身体半径
}                                                                 // PetMetrics 结束

// MARK: - 视图入口                                                      // 分节：入口

/// 3D 伙伴。jumpToken / flipToken 每加 1 播一次动作，用整数触发避免动画自己重播
struct PetSceneView: UIViewRepresentable {                        // 3D 视图
    let stage: PetStage                                           // 成长阶段，决定帽子与体型
    var jumpToken: Int = 0                                        // 投喂时 +1
    var flipToken: Int = 0                                        // 拨穗时 +1

    @Environment(\.accessibilityReduceMotion) private var reduceMotion // 系统「减弱动态效果」
    @AppStorage("app.pet.static3D") private var staticMode = false     // 应用内省电开关

    /// 两个开关任一打开就不放动画：省电、省电、也照顾前庭敏感的人
    private var animationsOff: Bool { staticMode || reduceMotion } // 是否关闭动效

    func makeUIView(context: Context) -> ARView {                 // 建场景
        let view = ARView(frame: .zero,                           // 不用 SwiftUI 的 ARView（那是 ARKit 的相机视图）
                          cameraMode: .nonAR,                     // 不启用摄像头，纯 3D 摆件
                          automaticallyConfigureSession: false)   // 不配置 AR 会话，避免申请相机权限
        view.environment.background = .color(UIColor(red: 0.95, green: 0.95, blue: 0.97, alpha: 1)) // 与卡片底色一致
        view.renderOptions.insert(.disableMotionBlur)             // 关动态模糊，省电也稳
        PetSceneBuilder.installCamera(on: view)                   // 放一台固定相机
        let pet = PetSceneBuilder.build(stage: stage)             // 搭宠物
        let anchor = AnchorEntity()                               // 世界原点锚点
        anchor.addChild(pet)                                      // 挂上宠物
        view.scene.addAnchor(anchor)                              // 加入场景
        context.coordinator.pet = pet                             // 存引用便于播动画
        context.coordinator.tassel = pet.findEntity(named: PetSceneBuilder.tasselName) // 找流苏节点
        context.coordinator.stage = stage                         // 记下当前阶段
        context.coordinator.animationsOff = animationsOff          // 同步动效开关
        if !animationsOff { context.coordinator.playIdle() }       // 开着就轻微起伏
        return view                                               // 返回
    }                                                             // makeUIView 结束

    func updateUIView(_ view: ARView, context: Context) {         // 状态变化时
        let coordinator = context.coordinator                     // 拿协调器
        if stage != coordinator.stage {                           // 阶段变了
            coordinator.stage = stage                             // 更新记录
            coordinator.rebuild(stage: stage)                     // 重建宠物
        }                                                         // 分支结束
        if animationsOff != coordinator.animationsOff {            // 动效开关变了
            coordinator.animationsOff = animationsOff              // 同步
            coordinator.rebuild(stage: stage)                      // 重建回静止姿态
        }                                                         // 分支结束
        if jumpToken != coordinator.lastJump {                    // 要求跳
            coordinator.lastJump = jumpToken                      // 记下
            if jumpToken > 0 { coordinator.jump() }               // 第一次进入不播
        }                                                         // 分支结束
        if flipToken != coordinator.lastFlip {                    // 要求拨穗
            coordinator.lastFlip = flipToken                      // 记下
            if flipToken > 0 { coordinator.flipTassel() }         // 第一次进入不播
        }                                                         // 分支结束
    }                                                             // updateUIView 结束

    func makeCoordinator() -> Coordinator { Coordinator() }       // 建协调器

    // MARK: - 协调器                                                  // 分节：协调器

    final class Coordinator {                                     // 持有节点与动画状态
        var pet: Entity?                                          // 宠物根节点
        var tassel: Entity?                                       // 流苏节点
        var stage: PetStage?                                      // 当前阶段
        var lastJump = 0                                          // 上次跳跃 token
        var lastFlip = 0                                          // 上次拨穗 token
        var animationsOff = false                                 // 是否关闭动效

        func rebuild(stage: PetStage) {                           // 重建宠物
            guard let pet = pet, let parent = pet.parent else { return } // 没节点就不动
            pet.removeFromParent()                                // 移除旧的
            let fresh = PetSceneBuilder.build(stage: stage)         // 建新的
            parent.addChild(fresh)                                // 挂回去
            self.pet = fresh                                      // 更新引用
            self.tassel = fresh.findEntity(named: PetSceneBuilder.tasselName) // 重新找流苏
            if !animationsOff { playIdle() }                       // 开着动效才继续起伏
        }                                                         // rebuild 结束

        func playIdle() {                                         // 轻微上下起伏
            guard !animationsOff else { return }                   // 关掉动效就不播
            guard let pet = pet else { return }                    // 没节点就退出
            var up = pet.transform                                // 上升姿态
            up.translation.y += 0.03                              // 抬 3 厘米
            let move = FromToByAnimation<Transform>(from: pet.transform, // 起点
                                                    to: up,       // 终点
                                                    duration: 1.6, // 单程时长
                                                    timing: .easeInOut, // 缓入缓出
                                                    bindTarget: .transform) // 作用在变换上
            guard let resource = try? AnimationResource.generate(with: move) else { return } // 生成资源
            pet.playAnimation(resource.repeat(count: 9_999))       // 来回起伏
        }                                                         // playIdle 结束

        func jump() {                                             // 投喂后跳一下
            guard !animationsOff else { return }                   // 关掉动效就不播
            guard let pet = pet else { return }                    // 没节点就退出
            let base = pet.transform                              // 原地姿态
            var up = base                                         // 上升姿态
            up.translation.y += 0.18                              // 抬 18 厘米
            let lift = FromToByAnimation<Transform>(from: base, to: up, // 起跳
                                                    duration: 0.18, timing: .easeOut, bindTarget: .transform) // 快起
            let fall = FromToByAnimation<Transform>(from: up, to: base, // 落下
                                                    duration: 0.26, timing: .easeIn, bindTarget: .transform) // 慢落
            guard let first = try? AnimationResource.generate(with: lift), // 起跳资源
                  let second = try? AnimationResource.generate(with: fall) else { return } // 落下资源
            pet.playAnimation(first)                              // 播起跳
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) { // 起跳结束后
                pet.playAnimation(second)                         // 播落下
            }                                                     // 延迟结束
        }                                                         // jump 结束

        func flipTassel() {                                       // 拨穗：流苏从右拨到左
            guard !animationsOff else { return }                   // 关掉动效就不播
            guard let tassel = tassel else { return }              // 没流苏就退出
            let start = tassel.transform                          // 起始姿态
            var end = start                                       // 结束姿态
            end.rotation = simd_quatf(angle: .pi, axis: [0, 1, 0]) * start.rotation // 绕自身竖轴转半圈
            let swing = FromToByAnimation<Transform>(from: start, to: end, // 拨动
                                                     duration: 0.7, timing: .easeInOut, bindTarget: .transform) // 慢速划过
            guard let resource = try? AnimationResource.generate(with: swing) else { return } // 生成资源
            tassel.playAnimation(resource)                        // 播一次
        }                                                         // flipTassel 结束
    }                                                             // Coordinator 结束
}                                                                 // PetSceneView 结束

// MARK: - 建模                                                          // 分节：建模

enum PetSceneBuilder {                                            // 宠物建模器
    static let tasselName = "pet.tassel"                          // 流苏节点名，动画要按名字找

    /// 放一台固定相机：略高于宠物、正前方 1.5 米，45° 视角
    static func installCamera(on view: ARView) {                  // 装相机
        let camera = PerspectiveCamera()                          // 相机实体
        camera.camera.fieldOfViewInDegrees = 45                   // 视角
        let holder = AnchorEntity(world: [0, 0.62, 1.5])          // 相机位置
        holder.addChild(camera)                                   // 挂上相机
        view.scene.addAnchor(holder)                               // 加入场景
    }                                                             // installCamera 结束

    /// 搭一只戴学士帽的宠物。朝 +Z 方向面向相机
    static func build(stage: PetStage) -> Entity {                // 搭宠物
        let root = Entity()                                       // 根节点
        root.scale = [PetMetrics.petScale, PetMetrics.petScale, PetMetrics.petScale] // 整体缩小
        root.name = "pet.root"                                    // 便于调试查找

        let body = sphere(radius: PetMetrics.bodyRadius, color: PetPalette.body) // 身体
        body.position = [0, PetMetrics.bodyRadius, 0]             // 落在地台上
        body.scale = [1, 0.94, 1]                                 // 略压扁，显得圆润
        root.addChild(body)                                       // 挂上

        let belly = sphere(radius: 0.19, color: PetPalette.belly) // 肚皮
        belly.position = [0, 0.24, 0.13]                          // 前下方
        belly.scale = [1, 1.1, 0.6]                               // 压成片状
        root.addChild(belly)                                      // 挂上

        let head = sphere(radius: 0.22, color: PetPalette.body)   // 头
        head.position = [0, 0.60, 0]                              // 身体上方
        root.addChild(head)                                       // 挂上

        for side in [-1.0, 1.0] {                                 // 左右各一只
            let ear = sphere(radius: 0.075, color: PetPalette.body) // 耳朵
            ear.position = [Float(side) * 0.15, 0.77, 0]          // 头顶两侧
            ear.scale = [1, 1.2, 0.8]                             // 竖起来一点
            root.addChild(ear)                                    // 挂上

            let eye = sphere(radius: 0.035, color: PetPalette.eye) // 眼睛
            eye.position = [Float(side) * 0.085, 0.63, 0.19]      // 面部前方
            root.addChild(eye)                                    // 挂上

            let foot = sphere(radius: 0.08, color: PetPalette.body) // 脚
            foot.position = [Float(side) * 0.13, 0.055, 0.06]     // 身体下方
            foot.scale = [1, 0.6, 1.2]                            // 压扁
            root.addChild(foot)                                   // 挂上
        }                                                         // 循环结束

        let muzzle = sphere(radius: 0.075, color: PetPalette.belly) // 嘴部
        muzzle.position = [0, 0.55, 0.18]                         // 头前方
        muzzle.scale = [1.2, 0.9, 0.7]                            // 略扁
        root.addChild(muzzle)                                     // 挂上

        root.addChild(cap(stage: stage))                          // 挂学士帽

        let ground = ModelEntity(mesh: .generateCylinder(height: 0.01, radius: 0.42), // 地台
                                 materials: [material(PetPalette.ground)]) // 灰色
        ground.position = [0, 0.005, 0]                           // 贴地
        root.addChild(ground)                                     // 挂上
        return root                                               // 返回整只
    }                                                             // build 结束

    /// 学士帽：帽板 + 帽围 + 金环 + 流苏。流苏单独成节点，方便拨穗
    static func cap(stage: PetStage) -> Entity {                  // 造帽子
        let group = Entity()                                      // 帽子整体
        group.position = [0, 0.80, 0]                             // 头顶

        let crown = ModelEntity(mesh: .generateCylinder(height: 0.07, radius: 0.135), // 帽围
                                materials: [material(PetPalette.cap)]) // 深色
        crown.position = [0, 0, 0]                                // 居中
        group.addChild(crown)                                     // 挂上

        let board = ModelEntity(mesh: .generateBox(width: 0.34, height: 0.018, length: 0.34, cornerRadius: 0.004), // 方帽板
                                materials: [material(PetPalette.cap)]) // 深色
        board.position = [0, 0.045, 0]                            // 帽围上方
        group.addChild(board)                                     // 挂上

        let ring = ModelEntity(mesh: .generateCylinder(height: 0.016, radius: 0.142), // 金环
                               materials: [material(PetPalette.ring, metallic: true)]) // 金属金
        ring.position = [0, 0.022, 0]                             // 帽围上沿
        group.addChild(ring)                                      // 挂上

        let button = sphere(radius: 0.018, color: PetPalette.ring) // 帽顶扣
        button.position = [0, 0.058, 0]                           // 正中
        group.addChild(button)                                    // 挂上

        let tassel = Entity()                                     // 流苏节点（拨穗转它）
        tassel.name = tasselName                                  // 起名方便查找
        tassel.position = [0.17, 0.045, 0.05]                     // 帽檐右前方
        let cord = ModelEntity(mesh: .generateCylinder(height: 0.12, radius: 0.006), // 流苏绳
                               materials: [material(PetPalette.tassel)]) // 红色
        cord.position = [0, -0.06, 0]                             // 绳在节点下方
        tassel.addChild(cord)                                     // 挂上
        let knot = sphere(radius: 0.028, color: PetPalette.tassel) // 流苏头
        knot.position = [0, -0.13, 0]                             // 绳子末端
        knot.scale = [1, 1.3, 1]                                  // 拉长一点
        tassel.addChild(knot)                                     // 挂上
        group.addChild(tassel)                                    // 挂到帽子上

        if stage == .seed { group.scale = [0.86, 0.86, 0.86] }    // 幼体帽子小一号
        return group                                              // 返回帽子
    }                                                             // cap 结束

    // MARK: - 小工具                                                  // 分节：工具

    /// 造一个球
    static func sphere(radius: Float, color: UIColor) -> ModelEntity { // 球体
        ModelEntity(mesh: .generateSphere(radius: radius), materials: [material(color)]) // 直接返回
    }                                                             // sphere 结束

    /// 造一个材质。粗糙度调高一点，避免像塑料
    static func material(_ color: UIColor, metallic: Bool = false) -> SimpleMaterial { // 材质
        SimpleMaterial(color: color, roughness: .float(0.55), isMetallic: metallic) // 哑光为主
    }                                                             // material 结束
}                                                                 // PetSceneBuilder 结束
