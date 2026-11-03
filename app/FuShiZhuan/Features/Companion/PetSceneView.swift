//  PetSceneView.swift —— 伙伴形象：一只直立的猫（程序化几何体）          // 文件说明
//  坐标全部照抄 Web 样板 public/js/pet.js 的 buildPet()，单位与原版一致：
//    +X 向右、+Y 向上、+Z 朝向相机；整只缩放 0.8，根节点抬高 0.02          // 坐标系约定
//  样板本来就是「人形站姿的猫」，所以 iOS 端不做二次设计，只做忠实移植       // 移植原则
//  只用 generateSphere / generateCone / generateCylinder / generateBox     // 网格约束
//  （RealityKit 没有 generateTorus，样板的半环 ω 嘴改用小球沿弧线串成）     // 替代方案

import RealityKit  // 3D 引擎
import SwiftUI  // 界面框架
import UIKit  // UIColor

// MARK: - 配色与尺寸                                                  // 分节：常量

enum CatPalette {  // 猫的固定用色（毛色不在这里，来自配件表）
    static let eye = UIColor(hex: "2B3040")  // 眼睛：样板的深灰蓝
    static let eyeShine = UIColor(hex: "FFFFFF")  // 眼里的高光点
    static let pink = UIColor(hex: "FFA8BD")  // 鼻头、内耳、腮红：样板粉
    static let whisker = UIColor(hex: "F2F2F6")  // 胡须：近白
    static let mouth = UIColor(hex: "2B3040")  // 嘴：深灰
    static let cord = UIColor(hex: "EF3B30")  // 流苏红绳
    static let cordDeep = UIColor(hex: "C4241C")  // 流苏穗子：暗一档的红
    static let gold = UIColor(hex: "FFC93C")  // 流苏金扣与金环
    static let shadow = UIColor(hex: "E3E7F0")  // 地台投影：比卡片底色深一点点
}  // CatPalette 结束

enum CatMetrics {  // 尺寸与节点名（全部为样板原始单位）
    static let petScale: Float = 0.8  // 整只缩放，与样板 PET_SCALE 一致
    static let rootY: Float = 0.02  // 根节点抬高，与样板 g.position.y 一致
    static let headY: Float = 0.6  // 头组高度，与样板 H.position.y 一致
    static let tailName = "cat.tail"  // 尾巴节点名，摆尾动画按名字找
}  // CatMetrics 结束

// MARK: - 视图入口                                                    // 分节：入口

/// 3D 伙伴（直立的猫）。jumpToken / flipToken / wagToken 每加 1 播一次动作
struct PetSceneView: UIViewRepresentable {  // 3D 视图
    let stage: PetStage  // 成长阶段，决定帽子大小
    var outfit: CatOutfit = .default  // 当前穿戴
    var jumpToken: Int = 0  // 投喂时 +1
    var flipToken: Int = 0  // 拨穗时 +1
    var wagToken: Int = 0  // 摸头时 +1，尾巴摆一下

    @Environment(\.accessibilityReduceMotion) private var reduceMotion  // 系统「减弱动态效果」
    @AppStorage("app.pet.static3D") private var staticMode = false  // 应用内省电开关

    private var animationsOff: Bool { staticMode || reduceMotion }  // 两个开关任一打开就不放动画

    func makeUIView(context: Context) -> ARView {  // 建场景
        let view = ARView(frame: .zero,  // 不用 SwiftUI 的 ARView（那是 ARKit 相机视图）
                          cameraMode: .nonAR,  // 不启用摄像头，纯 3D 摆件
                          automaticallyConfigureSession: false)  // 不配置 AR 会话，避免要相机权限
        view.environment.background = .color(UIColor(hex: "F2F3F7"))  // 与卡片底色一致
        view.renderOptions.insert(.disableMotionBlur)  // 关动态模糊，省电也稳
        PetSceneBuilder.installCamera(on: view)  // 放一台固定相机
        let cat = PetSceneBuilder.build(stage: stage, outfit: outfit)  // 搭猫
        let anchor = AnchorEntity()  // 世界原点锚点
        anchor.addChild(cat)  // 挂上猫
        view.scene.addAnchor(anchor)  // 加入场景
        context.coordinator.pet = cat  // 存引用便于播动画
        context.coordinator.tassel = cat.findEntity(named: PetSceneBuilder.tasselName)  // 找流苏节点
        context.coordinator.tail = cat.findEntity(named: CatMetrics.tailName)  // 找尾巴节点
        context.coordinator.stage = stage  // 记下当前阶段
        context.coordinator.outfit = outfit  // 记下当前穿戴
        context.coordinator.animationsOff = animationsOff  // 同步动效开关
        if !animationsOff { context.coordinator.playIdle() }  // 开着就轻微起伏
        return view  // 返回
    }  // makeUIView 结束

    func updateUIView(_ view: ARView, context: Context) {  // 状态变化时
        let coordinator = context.coordinator  // 拿协调器
        if stage != coordinator.stage || outfit != coordinator.outfit {  // 阶段或穿戴变了
            coordinator.stage = stage  // 更新记录
            coordinator.outfit = outfit  // 更新穿戴
            coordinator.rebuild(stage: stage, outfit: outfit)  // 重建猫
        }  // 分支结束
        if animationsOff != coordinator.animationsOff {  // 动效开关变了
            coordinator.animationsOff = animationsOff  // 同步
            coordinator.rebuild(stage: stage, outfit: outfit)  // 重建回静止姿态
        }  // 分支结束
        if jumpToken != coordinator.lastJump {  // 要求跳
            coordinator.lastJump = jumpToken  // 记下
            if jumpToken > 0 { coordinator.jump() }  // 第一次进入不播
        }  // 分支结束
        if flipToken != coordinator.lastFlip {  // 要求拨穗
            coordinator.lastFlip = flipToken  // 记下
            if flipToken > 0 { coordinator.flipTassel() }  // 第一次进入不播
        }  // 分支结束
        if wagToken != coordinator.lastWag {  // 要求摆尾
            coordinator.lastWag = wagToken  // 记下
            if wagToken > 0 { coordinator.wagTail() }  // 第一次进入不播
        }  // 分支结束
    }  // updateUIView 结束

    func makeCoordinator() -> Coordinator { Coordinator() }  // 建协调器

    // MARK: - 协调器                                                  // 分节：协调器

    final class Coordinator {  // 持有节点与动画状态
        var pet: Entity?  // 猫根节点
        var tassel: Entity?  // 流苏节点
        var tail: Entity?  // 尾巴节点
        var stage: PetStage?  // 当前阶段
        var outfit: CatOutfit?  // 当前穿戴
        var lastJump = 0  // 上次跳跃 token
        var lastFlip = 0  // 上次拨穗 token
        var lastWag = 0  // 上次摆尾 token
        var animationsOff = false  // 是否关闭动效

        func rebuild(stage: PetStage, outfit: CatOutfit) {  // 重建猫
            guard let pet = pet, let parent = pet.parent else { return }  // 没节点就不动
            let base = pet.transform  // 记住当前姿态（起伏动画改过它）
            pet.removeFromParent()  // 移除旧的
            let fresh = PetSceneBuilder.build(stage: stage, outfit: outfit)  // 建新的
            fresh.transform = base  // 回到同一姿态
            parent.addChild(fresh)  // 挂回去
            self.pet = fresh  // 更新引用
            self.tassel = fresh.findEntity(named: PetSceneBuilder.tasselName)  // 重新找流苏
            self.tail = fresh.findEntity(named: CatMetrics.tailName)  // 重新找尾巴
            if !animationsOff { playIdle() }  // 开着动效才继续起伏
        }  // rebuild 结束

        func playIdle() {  // 轻微上下起伏
            guard !animationsOff else { return }  // 关掉动效就不播
            guard let pet = pet else { return }  // 没节点就退出
            var up = pet.transform  // 上升姿态
            up.translation.y += 0.02  // 抬 2 厘米（按 0.8 缩放后的观感）
            let move = FromToByAnimation<Transform>(from: pet.transform,  // 起点
                                                    to: up,  // 终点
                                                    duration: 1.8,  // 单程时长
                                                    timing: .easeInOut,  // 缓入缓出
                                                    bindTarget: .transform)  // 作用在变换上
            guard let resource = try? AnimationResource.generate(with: move) else { return }  // 生成资源
            pet.playAnimation(resource.repeat(count: 9_999))  // 来回起伏
        }  // playIdle 结束

        func jump() {  // 投喂后跳一下
            guard !animationsOff else { return }  // 关掉动效就不播
            guard let pet = pet else { return }  // 没节点就退出
            let base = pet.transform  // 原地姿态
            var up = base  // 上升姿态
            up.translation.y += 0.16  // 抬 16 厘米
            let lift = FromToByAnimation<Transform>(from: base, to: up,  // 起跳
                                                    duration: 0.18, timing: .easeOut, bindTarget: .transform)  // 快起
            let fall = FromToByAnimation<Transform>(from: up, to: base,  // 落下
                                                    duration: 0.26, timing: .easeIn, bindTarget: .transform)  // 慢落
            guard let first = try? AnimationResource.generate(with: lift),  // 起跳资源
                  let second = try? AnimationResource.generate(with: fall) else { return }  // 落下资源
            pet.playAnimation(first)  // 播起跳
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {  // 起跳结束后
                pet.playAnimation(second)  // 播落下
            }  // 延迟结束
        }  // jump 结束

        func flipTassel() {  // 拨穗：流苏从右拨到左
            guard !animationsOff else { return }  // 关掉动效就不播
            guard let tassel = tassel else { return }  // 没流苏就退出
            let start = tassel.transform  // 起始姿态
            var end = start  // 结束姿态
            end.rotation = simd_quatf(angle: .pi, axis: [0, 1, 0]) * start.rotation  // 绕自身竖轴转半圈
            let swing = FromToByAnimation<Transform>(from: start, to: end,  // 拨动
                                                     duration: 0.7, timing: .easeInOut, bindTarget: .transform)  // 慢速划过
            guard let resource = try? AnimationResource.generate(with: swing) else { return }  // 生成资源
            tassel.playAnimation(resource)  // 播一次
        }  // flipTassel 结束

        func wagTail() {  // 摸头：尾巴摆一下
            guard !animationsOff else { return }  // 关掉动效就不播
            guard let tail = tail else { return }  // 没尾巴就退出
            let start = tail.transform  // 起始姿态
            var end = start  // 结束姿态
            end.rotation = simd_quatf(angle: .pi / 5, axis: [0, 1, 0]) * start.rotation  // 绕竖轴摆 36 度
            let swing = FromToByAnimation<Transform>(from: start, to: end,  // 摆出去
                                                     duration: 0.22, timing: .easeOut, bindTarget: .transform)  // 快摆
            let back = FromToByAnimation<Transform>(from: end, to: start,  // 摆回来
                                                    duration: 0.28, timing: .easeInOut, bindTarget: .transform)  // 慢回
            guard let first = try? AnimationResource.generate(with: swing),  // 摆出资源
                  let second = try? AnimationResource.generate(with: back) else { return }  // 摆回资源
            tail.playAnimation(first)  // 先摆出去
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {  // 到最外侧
                tail.playAnimation(second)  // 再摆回来
            }  // 延迟结束
        }  // wagTail 结束
    }  // Coordinator 结束
}  // PetSceneView 结束

// MARK: - 建模                                                        // 分节：建模

enum PetSceneBuilder {  // 猫建模器
    static let tasselName = "cat.tassel"  // 流苏节点名
    static let catalog = OutfitCatalog.shared  // 配件表全局共用

    /// 放一台固定相机：位置与视角照抄样板（camera 38° / (0,0.55,4.6) / 看向 (0,0.05,0)）
    static func installCamera(on view: ARView) {  // 装相机
        let camera = PerspectiveCamera()  // 相机实体
        camera.camera.fieldOfViewInDegrees = 38  // 与样板 PerspectiveCamera(38,...) 一致
        camera.camera.near = 0.1  // 与样板一致
        camera.camera.far = 100  // 与样板一致
        let holder = AnchorEntity(world: [0, 0.55, 4.6])  // 与样板 camera.position 一致
        holder.addChild(camera)  // 挂上相机
        view.scene.addAnchor(holder)  // 加入场景
    }  // installCamera 结束

    /// 搭一只直立的猫，朝 +Z 面向相机
    static func build(stage: PetStage, outfit: CatOutfit) -> Entity {  // 搭猫
        let root = Entity()  // 根节点
        root.name = "pet.root"  // 便于调试查找
        let fur = furColor(outfit: outfit, accent: false)  // 毛色
        let cream = furColor(outfit: outfit, accent: true)  // 肚皮与腮的浅色

        root.addChild(shadowDisc())  // 脚下投影
        root.addChild(legs(fur: fur, cream: cream))  // 两条腿与脚掌
        root.addChild(bodyBlock(fur: fur, cream: cream))  // 身体与白肚皮
        root.addChild(arms(fur: fur, cream: cream))  // 两臂垂在身侧

        let headBlock = head(fur: fur, cream: cream)  // 头（含五官与额纹）
        headBlock.addChild(headWear(stage: stage, outfit: outfit))  // 帽子眼镜挂头上，与样板一致
        root.addChild(headBlock)  // 挂上头

        root.addChild(tail(fur: fur, cream: cream))  // 尾巴从后腰翘起
        root.addChild(bodyWear(outfit: outfit))  // 围巾与背包

        root.position = [0, CatMetrics.rootY, 0]  // 与样板 g.position.y = 0.02 一致
        root.scale = [CatMetrics.petScale, CatMetrics.petScale, CatMetrics.petScale]  // 与样板 PET_SCALE 一致
        return root  // 返回整只
    }  // build 结束

    // MARK: - 腿与身体                                              // 分节：身体

    static func legs(fur: UIColor, cream: UIColor) -> Entity {  // 两条短粗腿
        let group = Entity()  // 腿整体
        for side in [-1.0, 1.0] {  // 左右各一
            let s = Float(side)  // 侧别转成 Float 省得反复转换
            let leg = sphere(radius: 0.15, color: fur)  // 腿（样板是胶囊，用竖椭圆近似）
            leg.position = [s * 0.21, -0.72, 0]  // 与样板 leg.position 一致
            leg.scale = [1, 1.8, 1]  // 拉伸成柱状，总高约 0.54
            group.addChild(leg)  // 挂上

            let foot = sphere(radius: 0.2, color: cream)  // 脚掌白毛
            foot.position = [s * 0.22, -0.92, 0.1]  // 与样板 foot.position 一致
            foot.scale = [1, 0.6, 1.28]  // 压扁并往前伸
            group.addChild(foot)  // 挂上
        }  // 循环结束
        return group  // 返回腿
    }  // legs 结束

    static func bodyBlock(fur: UIColor, cream: UIColor) -> Entity {  // 身体与白肚皮
        let group = Entity()  // 身体整体
        let body = sphere(radius: 0.5, color: fur)  // 身体（上宽下窄的梨形）
        body.position = [0, -0.1, 0]  // 与样板 bodyMesh.position 一致
        body.scale = [0.95, 0.92, 0.8]  // 与样板 scale 一致
        group.addChild(body)  // 挂上

        let belly = sphere(radius: 0.4, color: cream)  // 白肚皮
        belly.position = [0, -0.16, 0.24]  // 与样板 belly.position 一致
        belly.scale = [0.8, 0.86, 0.46]  // 贴在前胸
        group.addChild(belly)  // 挂上
        return group  // 返回身体
    }  // bodyBlock 结束

    static func arms(fur: UIColor, cream: UIColor) -> Entity {  // 两臂与白手套
        let group = Entity()  // 手臂整体
        for side in [-1.0, 1.0] {  // 左右各一
            let s = Float(side)  // 侧别
            let armGroup = Entity()  // 单侧手臂组，方便摆动
            armGroup.position = [s * 0.49, 0.06, 0.06]  // 与样板 armGroup.position 一致
            armGroup.orientation = simd_quatf(angle: s * 0.14, axis: [0, 0, 1])  // 稍微外张，不贴身体

            let upper = sphere(radius: 0.098, color: fur)  // 上臂（样板是胶囊）
            upper.position = [0, -0.17, 0]  // 与样板 upper.position 一致
            upper.scale = [1, 2.02, 1]  // 拉长到样板胶囊的 0.396 总高
            armGroup.addChild(upper)  // 挂上

            let hand = sphere(radius: 0.145, color: cream)  // 手（白手套）
            hand.position = [0, -0.38, 0.03]  // 与样板 hand.position 一致
            armGroup.addChild(hand)  // 挂上
            group.addChild(armGroup)  // 挂到整体
        }  // 循环结束
        return group  // 返回手臂
    }  // arms 结束

    // MARK: - 头部                                                  // 分节：头部

    static func head(fur: UIColor, cream: UIColor) -> Entity {  // 头与五官
        let group = Entity()  // 头部整体
        group.name = "cat.head"  // 便于查找
        group.position = [0, CatMetrics.headY, 0]  // 与样板 H.position.y = 0.6 一致

        let skull = sphere(radius: 0.65, color: fur)  // 头（大脸，占整体四成）
        skull.scale = [1.08, 0.98, 1.0]  // 与样板 head.scale 一致
        group.addChild(skull)  // 挂上

        group.addChild(ears(fur: fur))  // 尖耳与粉色内耳
        group.addChild(face(fur: fur, cream: cream))  // 腮、腮红、眼、鼻、嘴、胡须、额纹
        return group  // 返回头
    }  // head 结束

    static func ears(fur: UIColor) -> Entity {  // 尖耳 + 粉色内耳
        let group = Entity()  // 耳朵整体
        for side in [-1.0, 1.0] {  // 左右各一
            let s = Float(side)  // 侧别
            let qz = simd_quatf(angle: -s * 0.3, axis: [0, 0, 1])  // 往外歪，与样板 rotation.z 一致
            let qx = simd_quatf(angle: -0.12, axis: [1, 0, 0])  // 稍往前倾，与样板 rotation.x 一致

            let ear = ModelEntity(mesh: .generateCone(height: 0.36, radius: 0.21),  // 外耳：锥体
                                  materials: [material(fur)])  // 毛色
            ear.position = [s * 0.4, 0.5, -0.02]  // 与样板 ear.position 一致
            ear.orientation = qx * qz  // 样板欧拉顺序 XYZ：先歪再倾
            group.addChild(ear)  // 挂上

            let inner = ModelEntity(mesh: .generateCone(height: 0.23, radius: 0.125),  // 内耳
                                    materials: [material(CatPalette.pink)])  // 粉色
            inner.position = [s * 0.4, 0.49, 0.07]  // 与样板 inner.position 一致
            inner.orientation = qx * qz  // 同角度
            group.addChild(inner)  // 挂上
        }  // 循环结束
        return group  // 返回耳朵
    }  // ears 结束

    static func face(fur: UIColor, cream: UIColor) -> Entity {  // 腮、腮红、眼、鼻、嘴、胡须、额纹
        let group = Entity()  // 面部整体
        for side in [-1.0, 1.0] {  // 左右对称的部分
            let s = Float(side)  // 侧别

            let cheek = sphere(radius: 0.25, color: cream)  // 腮部白毛（没有这个猫脸就是块圆面包）
            cheek.position = [s * 0.29, -0.15, 0.49]  // 与样板 cheek.position 一致
            cheek.scale = [1, 0.8, 0.52]  // 压成片贴在脸上
            group.addChild(cheek)  // 挂上

            let blush = sphere(radius: 0.115, color: CatPalette.pink)  // 腮红（卡通脸的关键）
            blush.position = [s * 0.42, -0.06, 0.5]  // 与样板 blush.position 一致
            blush.scale = [1, 0.6, 0.25]  // 极薄一片
            group.addChild(blush)  // 挂上

            let eye = sphere(radius: 0.135, color: CatPalette.eye)  // 眼睛
            eye.position = [s * 0.24, 0.06, 0.55]  // 与样板 eye.position 一致
            eye.scale = [1, 1.25, 0.7]  // 竖椭圆
            group.addChild(eye)  // 挂上

            let shine = sphere(radius: 0.045, color: CatPalette.eyeShine)  // 高光点（大）
            shine.position = [s * 0.24 + 0.04, 0.12, 0.63]  // 与样板 shine.position 一致
            group.addChild(shine)  // 挂上

            let shine2 = sphere(radius: 0.022, color: CatPalette.eyeShine)  // 高光点（小）
            shine2.position = [s * 0.24 - 0.045, -0.02, 0.63]  // 与样板 shine2.position 一致
            group.addChild(shine2)  // 挂上

            for i in 0..<3 {  // 每侧三根胡须
                let dy: Float = [Float(0.03), -0.02, -0.07][i]  // 样板的三档高度差
                let whisker = ModelEntity(mesh: .generateCylinder(height: 0.36, radius: 0.007),  // 细杆
                                          materials: [material(CatPalette.whisker)])  // 近白色
                whisker.position = [s * 0.34, -0.1 + dy, 0.63]  // 与样板 w.position 一致
                let qz = simd_quatf(angle: s * (.pi / 2 - 0.06 - Float(i) * 0.16), axis: [0, 0, 1])  // 放平并逐根错开
                let qy = simd_quatf(angle: s * 0.34, axis: [0, 1, 0])  // 往外撇
                whisker.orientation = qy * qz  // 样板欧拉顺序 XYZ：先转 Z 再转 Y
                group.addChild(whisker)  // 挂上
            }  // 胡须循环结束

            group.addChild(lipArc(center: [s * 0.052, -0.155, 0.627]))  // ω 嘴的左右两撇
        }  // 循环结束

        let nose = ModelEntity(mesh: .generateCone(height: 0.068, radius: 0.05),  // 鼻头（样板是三棱锥）
                               materials: [material(CatPalette.pink)])  // 粉色
        nose.position = [0, -0.1, 0.64]  // 与样板 nose.position 一致
        nose.orientation = simd_quatf(angle: .pi, axis: [1, 0, 0])  // 倒过来，尖朝下
        group.addChild(nose)  // 挂上

        for dx in [Float(-0.085), 0, 0.085] {  // 额头三道橘纹
            let stripe = ModelEntity(mesh: .generateCylinder(height: 0.17, radius: 0.016),  // 细纹
                                     materials: [material(darken(fur, by: 0.16))])  // 比毛色深一档
            stripe.position = [dx, 0.47, 0.5]  // 与样板 stripe.position 一致
            stripe.orientation = simd_quatf(angle: 0.46, axis: [1, 0, 0])  // 顺着额头斜面
            group.addChild(stripe)  // 挂上
        }  // 循环结束
        return group  // 返回面部
    }  // face 结束

    /// ω 嘴的一撇：RealityKit 没有半环网格，用小球沿下半圆弧串成（样板是 TorusGeometry 半环）
    static func lipArc(center: SIMD3<Float>) -> Entity {  // 一撇嘴
        let group = Entity()  // 这一撇整体
        let radius: Float = 0.052  // 样板 TorusGeometry 的半径
        let steps = 8  // 分八段，足够顺滑
        for i in 0...steps {  // 沿弧采样
            let theta = Float.pi + Float.pi * Float(i) / Float(steps)  // π→2π 正好是下半圆
            let bead = sphere(radius: 0.0085, color: CatPalette.mouth)  // 一颗嘴线小球
            bead.position = center + [cos(theta) * radius, sin(theta) * radius, 0]  // 摆到弧上
            group.addChild(bead)  // 挂上
        }  // 循环结束
        return group  // 返回一撇
    }  // lipArc 结束

    // MARK: - 尾巴                                                  // 分节：尾巴

    static func tail(fur: UIColor, cream: UIColor) -> Entity {  // 尾巴：从后腰往右上方翘
        let pivot = Entity()  // 尾巴根部节点，摆尾转它
        pivot.name = CatMetrics.tailName  // 起名方便查找
        pivot.position = [0.4, -0.76, -0.52]  // 与样板 tail.position 一致
        pivot.orientation = simd_quatf(angle: -0.45, axis: [0, 0, 1])  // 与样板 tail.rotation.z 一致

        let t1 = sphere(radius: 0.13, color: fur)  // 根部最粗
        t1.position = [0, 0, 0]  // 原点
        pivot.addChild(t1)  // 挂上

        let t25 = sphere(radius: 0.104, color: fur)  // 第二段（夹在中间补缝）
        t25.position = [0.2, 0.23, 0.01]  // 与样板 t25.position 一致
        pivot.addChild(t25)  // 挂上

        let t2 = sphere(radius: 0.112, color: fur)  // 第三段
        t2.position = [0.14, 0.15, 0]  // 与样板 t2.position 一致
        pivot.addChild(t2)  // 挂上

        let t3 = sphere(radius: 0.095, color: fur)  // 第四段
        t3.position = [0.25, 0.31, 0]  // 与样板 t3.position 一致
        pivot.addChild(t3)  // 挂上

        let t4 = sphere(radius: 0.084, color: fur)  // 第五段
        t4.position = [0.285, 0.38, 0.01]  // 与样板 t4.position 一致
        pivot.addChild(t4)  // 挂上

        let tip = sphere(radius: 0.072, color: cream)  // 尾尖一撮白毛
        tip.position = [0.31, 0.45, 0]  // 与样板 tTip.position 一致
        pivot.addChild(tip)  // 挂上
        return pivot  // 返回尾巴根
    }  // tail 结束

    static func shadowDisc() -> Entity {  // 脚下的柔和投影（样板是透明圆片，这里用近底色实心片）
        let disc = ModelEntity(mesh: .generateCylinder(height: 0.004, radius: 0.648),  // 薄圆片
                               materials: [material(CatPalette.shadow)])  // 比卡片底色略深
        disc.position = [0, -1.045, 0.06]  // 贴在脚掌下方
        disc.scale = [1, 1, 0.56]  // 压成椭圆，像俯视投影
        return disc  // 返回投影
    }  // shadowDisc 结束

    // MARK: - 头上配件                                              // 分节：帽子与眼镜

    static func headWear(stage: PetStage, outfit: CatOutfit) -> Entity {  // 帽子与眼镜（坐标是头组局部）
        let group = Entity()  // 配件整体
        let hat = catalog.item(id: outfit.id(for: .hat) ?? "")  // 头顶配件
        if let hat, hat.id != "hat.none" {  // 不是「不戴」
            group.addChild(hatEntity(hat, stage: stage))  // 装帽子
        }  // 分支结束
        let faceItem = catalog.item(id: outfit.id(for: .face) ?? "")  // 脸部配件
        if let faceItem, faceItem.id != "face.none" {  // 不是「不戴」
            group.addChild(glassesEntity(faceItem))  // 装眼镜
        }  // 分支结束
        return group  // 返回头部配件
    }  // headWear 结束

    static func bodyWear(outfit: CatOutfit) -> Entity {  // 围巾与背包（坐标是根节点局部）
        let group = Entity()  // 配件整体
        let neck = catalog.item(id: outfit.id(for: .neck) ?? "")  // 颈部配件
        if let neck, neck.id != "neck.none" {  // 不是「不戴」
            group.addChild(neckEntity(neck))  // 装围巾或项圈
        }  // 分支结束
        let back = catalog.item(id: outfit.id(for: .back) ?? "")  // 背部配件
        if let back, back.id != "back.none" {  // 不是「不戴」
            group.addChild(backEntity(back))  // 装背包或披风
        }  // 分支结束
        return group  // 返回身体配件
    }  // bodyWear 结束

    static func hatEntity(_ item: OutfitItem, stage: PetStage) -> Entity {  // 帽子（头组局部坐标）
        let group = Entity()  // 帽子整体
        let main = UIColor(hex: item.hex)  // 主色
        let accent = UIColor(hex: item.accent)  // 点缀色

        if item.id == "hat.graduate" {  // 学士帽：照抄样板的三件套 + 流苏
            let crown = ModelEntity(mesh: .generateCylinder(height: 0.1, radius: 0.26),  // 帽围
                                    materials: [material(main)])  // 主色（蓝）
            crown.position = [0, 0.68, 0]  // 与样板 capBase.position 一致
            group.addChild(crown)  // 挂上

            let board = ModelEntity(mesh: .generateBox(width: 0.66, height: 0.045, depth: 0.66, cornerRadius: 0.006),  // 方形帽板
                                    materials: [material(main)])  // 主色（蓝）
            board.position = [0, 0.75, 0]  // 与样板 capBoard.position 一致
            board.orientation = simd_quatf(angle: .pi / 4, axis: [0, 1, 0])  // 转 45°，与样板一致
            group.addChild(board)  // 挂上

            let edge = ModelEntity(mesh: .generateBox(width: 0.7, height: 0.014, depth: 0.7, cornerRadius: 0.004),  // 帽板亮边
                                   materials: [material(accent)])  // 浅蓝亮边
            edge.position = [0, 0.775, 0]  // 与样板 capEdge.position 一致
            edge.orientation = simd_quatf(angle: .pi / 4, axis: [0, 1, 0])  // 同角度
            group.addChild(edge)  // 挂上

            group.addChild(tasselNode())  // 挂流苏
        } else if item.id == "hat.beanie" {  // 毛线帽
            let dome = sphere(radius: 0.6, color: main)  // 半球（用球压扁）
            dome.scale = [1, 0.62, 1]  // 压成帽顶
            dome.position = [0, 0.62, 0]  // 盖住头顶
            group.addChild(dome)  // 挂上

            let brim = ModelEntity(mesh: .generateCylinder(height: 0.1, radius: 0.6),  // 帽檐
                                   materials: [material(main)])  // 主色
            brim.position = [0, 0.4, 0]  // 贴住额头
            group.addChild(brim)  // 挂上

            let pom = sphere(radius: 0.16, color: accent)  // 绒球
            pom.position = [0, 1.02, 0]  // 帽顶中央
            group.addChild(pom)  // 挂上
        } else if item.id == "hat.crown" {  // 小皇冠
            let band = ModelEntity(mesh: .generateCylinder(height: 0.12, radius: 0.32),  // 冠环
                                   materials: [material(main, metallic: true)])  // 金属
            band.position = [0, 0.78, 0]  // 压在头顶
            group.addChild(band)  // 挂上

            for i in 0..<5 {  // 五个尖
                let angle = Float(i) * (2 * .pi / 5)  // 均分一圈
                let spike = ModelEntity(mesh: .generateCone(height: 0.22, radius: 0.075),  // 冠尖
                                        materials: [material(main, metallic: true)])  // 金属
                spike.position = [cos(angle) * 0.28, 0.94, sin(angle) * 0.28]  // 沿环排布
                group.addChild(spike)  // 挂上
            }  // 循环结束

            let gem = sphere(radius: 0.06, color: accent)  // 正中宝石
            gem.position = [0, 0.8, 0.31]  // 正面
            group.addChild(gem)  // 挂上
        } else if item.id == "hat.headphones" {  // 耳机
            let band = ModelEntity(mesh: .generateBox(width: 0.72, height: 0.07, depth: 0.09, cornerRadius: 0.03),  // 横梁
                                   materials: [material(main)])  // 主色
            band.position = [0, 0.86, 0]  // 头顶上方
            group.addChild(band)  // 挂上

            for side in [-1.0, 1.0] {  // 左右耳罩
                let s = Float(side)  // 侧别
                let cup = ModelEntity(mesh: .generateCylinder(height: 0.14, radius: 0.15),  // 耳罩
                                      materials: [material(main)])  // 主色
                cup.position = [s * 0.36, 0.72, 0]  // 两侧
                cup.orientation = simd_quatf(angle: .pi / 2, axis: [0, 0, 1])  // 横放
                group.addChild(cup)  // 挂上

                let glow = sphere(radius: 0.045, color: accent)  // 指示灯光
                glow.position = [s * 0.44, 0.72, 0.02]  // 耳罩外侧
                group.addChild(glow)  // 挂上
            }  // 循环结束
        }  // 分支结束

        if stage == .seed { group.scale = [0.9, 0.9, 0.9] }  // 幼体帽子小一号
        return group  // 返回帽子
    }  // hatEntity 结束

    static func tasselNode() -> Entity {  // 流苏：帽顶金扣 → 斜拉帽檐 → 垂下 → 金环 → 五根穗
        let tassel = Entity()  // 流苏节点（头组局部坐标）
        tassel.name = tasselName  // 起名方便拨穗
        tassel.position = [0, 0.8, 0]  // 与样板 tassel.position 一致
        tassel.scale = [1.22, 1.22, 1.22]  // 与样板 tassel.scale 一致

        let knot = sphere(radius: 0.055, color: CatPalette.gold)  // 帽顶金扣
        knot.position = [0, 0.02, 0]  // 与样板 knot.position 一致
        tassel.addChild(knot)  // 挂上

        tassel.addChild(rod(from: [0, 0.02, 0], to: [0.34, -0.02, 0.22],  // 帽顶 → 帽檐
                            radius: 0.034, color: CatPalette.cord))  // 红绳
        tassel.addChild(rod(from: [0.34, -0.02, 0.22], to: [0.52, -0.2, 0.32],  // 帽檐 → 外侧
                            radius: 0.032, color: CatPalette.cord))  // 红绳
        tassel.addChild(rod(from: [0.52, -0.2, 0.32], to: [0.52, -0.56, 0.32],  // 外侧 → 垂直下垂
                            radius: 0.03, color: CatPalette.cord))  // 红绳

        let ring = ModelEntity(mesh: .generateCylinder(height: 0.05, radius: 0.052),  // 金环
                               materials: [material(CatPalette.gold, metallic: true)])  // 金属
        ring.position = [0.52, -0.57, 0.32]  // 与样板 ring.position 一致
        tassel.addChild(ring)  // 挂上

        let fringeTop = sphere(radius: 0.062, color: CatPalette.cordDeep)  // 穗子上端鼓包
        fringeTop.position = [0.52, -0.62, 0.32]  // 与样板 fringeTop.position 一致
        tassel.addChild(fringeTop)  // 挂上

        let offsets: [Float] = [-0.052, -0.026, 0, 0.026, 0.052]  // 样板五根穗的横向偏移
        for (i, dx) in offsets.enumerated() {  // 五根穗子
            let strand = ModelEntity(mesh: .generateCylinder(height: 0.28, radius: 0.017),  // 一根穗
                                     materials: [material(CatPalette.cordDeep)])  // 暗红
            strand.position = [0.52 + dx, -0.78, 0.32 + (i % 2 == 0 ? -0.022 : 0.022)]  // 与样板一致
            strand.orientation = simd_quatf(angle: dx * 2.2, axis: [0, 0, 1])  // 微微散开
            tassel.addChild(strand)  // 挂上
        }  // 循环结束
        return tassel  // 返回流苏
    }  // tasselNode 结束

    // MARK: - 眼镜、围巾、背包                                        // 分节：其他配件

    static func glassesEntity(_ item: OutfitItem) -> Entity {  // 眼镜（头组局部坐标）
        let group = Entity()  // 眼镜整体
        group.position = [0, 0.06, 0.55]  // 与眼睛同高同深
        let frame = UIColor(hex: item.hex)  // 框色
        let lens = UIColor(hex: item.accent)  // 镜片色

        for side in [-1.0, 1.0] {  // 左右镜片
            let s = Float(side)  // 侧别
            let glass = ModelEntity(mesh: .generateCylinder(height: 0.012, radius: 0.16),  // 镜片盘
                                    materials: [material(lens)])  // 镜片色
            glass.position = [s * 0.24, 0, 0.06]  // 对齐眼睛
            glass.orientation = simd_quatf(angle: .pi / 2, axis: [1, 0, 0])  // 立起来
            group.addChild(glass)  // 挂上

            let rim = ModelEntity(mesh: .generateCylinder(height: 0.02, radius: 0.175),  // 镜圈
                                  materials: [material(frame)])  // 框色
            rim.position = [s * 0.24, 0, 0.052]  // 镜片后一点
            rim.orientation = simd_quatf(angle: .pi / 2, axis: [1, 0, 0])  // 同镜片
            group.addChild(rim)  // 挂上

            let leg = ModelEntity(mesh: .generateCylinder(height: 0.3, radius: 0.012),  // 镜腿
                                  materials: [material(frame)])  // 框色
            leg.position = [s * 0.34, 0, -0.12]  // 往耳朵方向
            leg.orientation = simd_quatf(angle: .pi / 2, axis: [0, 1, 0])  // 横向
            group.addChild(leg)  // 挂上
        }  // 循环结束

        let bridge = ModelEntity(mesh: .generateBox(width: 0.16, height: 0.02, depth: 0.02, cornerRadius: 0.008),  // 鼻梁
                                 materials: [material(frame)])  // 框色
        bridge.position = [0, 0.02, 0.06]  // 两镜片之间
        group.addChild(bridge)  // 挂上
        return group  // 返回眼镜
    }  // glassesEntity 结束

    static func neckEntity(_ item: OutfitItem) -> Entity {  // 围巾或项圈（根节点局部坐标）
        let group = Entity()  // 颈部整体
        group.position = [0, 0.3, 0]  // 身体上沿，样板没有脖子所以压得低
        let main = UIColor(hex: item.hex)  // 主色
        let accent = UIColor(hex: item.accent)  // 点缀色

        if item.id.hasPrefix("neck.scarf") {  // 围巾
            let band = ModelEntity(mesh: .generateCylinder(height: 0.14, radius: 0.32),  // 围一圈
                                   materials: [material(main)])  // 主色
            band.scale = [1, 1, 0.86]  // 前后压薄
            group.addChild(band)  // 挂上

            let hang = ModelEntity(mesh: .generateBox(width: 0.14, height: 0.3, depth: 0.04, cornerRadius: 0.016),  // 垂下一截
                                   materials: [material(main)])  // 主色
            hang.position = [0.11, -0.2, 0.28]  // 胸前
            hang.orientation = simd_quatf(angle: 0.16, axis: [0, 0, 1])  // 稍微歪
            group.addChild(hang)  // 挂上

            let tip = ModelEntity(mesh: .generateBox(width: 0.146, height: 0.04, depth: 0.044, cornerRadius: 0.012),  // 流苏边
                                  materials: [material(accent)])  // 点缀色
            tip.position = [0.136, -0.35, 0.28]  // 垂片末端
            group.addChild(tip)  // 挂上
        } else if item.id == "neck.bell" {  // 铃铛项圈
            let band = ModelEntity(mesh: .generateCylinder(height: 0.08, radius: 0.3),  // 项圈
                                   materials: [material(main)])  // 主色
            band.scale = [1, 1, 0.88]  // 压薄
            group.addChild(band)  // 挂上

            let bell = sphere(radius: 0.08, color: accent)  // 铃铛
            bell.position = [0, -0.07, 0.29]  // 脖子正前
            group.addChild(bell)  // 挂上

            let hole = sphere(radius: 0.022, color: main)  // 铃铛上的孔
            hole.position = [0, -0.1, 0.35]  // 铃铛下方
            group.addChild(hole)  // 挂上
        } else if item.id == "neck.bowtie" {  // 领结
            for side in [-1.0, 1.0] {  // 左右两片
                let s = Float(side)  // 侧别
                let wing = ModelEntity(mesh: .generateBox(width: 0.14, height: 0.1, depth: 0.04, cornerRadius: 0.02),  // 一片翅膀
                                       materials: [material(main)])  // 主色
                wing.position = [s * 0.1, 0, 0.29]  // 分列两侧
                wing.orientation = simd_quatf(angle: s * 0.35, axis: [0, 1, 0])  // 微微外张
                group.addChild(wing)  // 挂上
            }  // 循环结束

            let knot = ModelEntity(mesh: .generateBox(width: 0.055, height: 0.08, depth: 0.05, cornerRadius: 0.02),  // 结
                                   materials: [material(accent)])  // 点缀色
            knot.position = [0, 0, 0.305]  // 正中
            group.addChild(knot)  // 挂上
        }  // 分支结束
        return group  // 返回颈部配件
    }  // neckEntity 结束

    static func backEntity(_ item: OutfitItem) -> Entity {  // 背包或披风（根节点局部坐标）
        let group = Entity()  // 背部整体
        let main = UIColor(hex: item.hex)  // 主色
        let accent = UIColor(hex: item.accent)  // 点缀色

        if item.id == "back.backpack" {  // 小书包
            group.position = [0, -0.1, -0.44]  // 背后
            let bag = ModelEntity(mesh: .generateBox(width: 0.4, height: 0.4, depth: 0.2, cornerRadius: 0.06),  // 包体
                                  materials: [material(main)])  // 主色
            group.addChild(bag)  // 挂上

            let flap = ModelEntity(mesh: .generateBox(width: 0.38, height: 0.2, depth: 0.045, cornerRadius: 0.03),  // 翻盖
                                   materials: [material(accent)])  // 点缀色
            flap.position = [0, 0.11, -0.1]  // 背面顶部
            group.addChild(flap)  // 挂上

            for side in [-1.0, 1.0] {  // 两条肩带
                let s = Float(side)  // 侧别
                let strap = ModelEntity(mesh: .generateCylinder(height: 0.5, radius: 0.024),  // 带子
                                        materials: [material(accent)])  // 点缀色
                strap.position = [s * 0.17, 0.0, 0.2]  // 绕到胸前
                strap.orientation = simd_quatf(angle: 0.2, axis: [1, 0, 0])  // 略微前倾
                group.addChild(strap)  // 挂上
            }  // 循环结束
        } else if item.id == "back.cape" {  // 披风
            group.position = [0, 0.16, -0.36]  // 肩后
            let cloth = ModelEntity(mesh: .generateBox(width: 0.66, height: 0.8, depth: 0.028, cornerRadius: 0.04),  // 披风布
                                    materials: [material(main)])  // 主色
            cloth.position = [0, -0.34, 0]  // 向下垂
            cloth.orientation = simd_quatf(angle: -0.18, axis: [1, 0, 0])  // 后摆
            group.addChild(cloth)  // 挂上

            let clasp = sphere(radius: 0.065, color: accent)  // 领扣
            clasp.position = [0, 0.06, 0.06]  // 颈部
            group.addChild(clasp)  // 挂上
        }  // 分支结束
        return group  // 返回背部配件
    }  // backEntity 结束

    // MARK: - 小工具                                                // 分节：工具

    static func furColor(outfit: CatOutfit, accent: Bool) -> UIColor {  // 取毛色
        let id = outfit.id(for: .fur) ?? "fur.orange"  // 当前毛色 id
        let item = catalog.item(id: id)  // 查配件表
        let hex = accent ? (item?.accent ?? "FFF7EE") : (item?.hex ?? "EC9440")  // 主色或点缀色
        return UIColor(hex: hex)  // 转成颜色
    }  // furColor 结束

    static func darken(_ color: UIColor, by amount: CGFloat) -> UIColor {  // 把颜色压暗一档
        var r: CGFloat = 0  // 红分量
        var g: CGFloat = 0  // 绿分量
        var b: CGFloat = 0  // 蓝分量
        var a: CGFloat = 0  // 透明度
        guard color.getRed(&r, green: &g, blue: &b, alpha: &a) else { return color }  // 取不到就原样返回
        return UIColor(red: max(0, r - amount), green: max(0, g - amount), blue: max(0, b - amount), alpha: a)  // 三通道同减
    }  // darken 结束

    static func sphere(radius: Float, color: UIColor) -> ModelEntity {  // 造一个球
        ModelEntity(mesh: .generateSphere(radius: radius), materials: [material(color)])  // 直接返回
    }  // sphere 结束

    /// 两点之间架一根圆柱（对应样板 tassel 的 seg 辅助函数）
    static func rod(from a: SIMD3<Float>, to b: SIMD3<Float>, radius: Float, color: UIColor) -> ModelEntity {  // 连点成杆
        let dir = b - a  // 方向向量
        let length = simd_length(dir)  // 杆长
        let entity = ModelEntity(mesh: .generateCylinder(height: length, radius: radius),  // 按长度造圆柱
                                 materials: [material(color)])  // 上材质
        entity.position = a + dir * 0.5  // 放在两点中点
        let unit = simd_normalize(dir)  // 单位方向
        if unit.y < -0.9999 {  // 正好朝下（样板第三段就是垂直下垂）
            entity.orientation = simd_quatf(angle: .pi, axis: [1, 0, 0])  // 绕 X 翻 180°，避免退化
        } else if unit.y > 0.9999 {  // 正好朝上
            entity.orientation = simd_quatf(angle: 0, axis: [0, 1, 0])  // 不用转
        } else {  // 一般情况
            entity.orientation = simd_quatf(from: [0, 1, 0], to: unit)  // 把 Y 轴对齐方向
        }  // 分支结束
        return entity  // 返回这根杆
    }  // rod 结束

    static func material(_ color: UIColor, metallic: Bool = false) -> SimpleMaterial {  // 造一个材质
        SimpleMaterial(color: color, roughness: .float(0.62), isMetallic: metallic)  // 哑光为主，像毛绒
    }  // material 结束
}  // PetSceneBuilder 结束
