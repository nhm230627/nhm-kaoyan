//  PetSceneView.swift —— 伙伴形象：一只猫（程序化几何体，不用外部资产）    // 文件说明
//  形象设定：坐姿家猫，大圆头 + 尖耳 + 长尾巴；颜色与配件全部来自 outfits.json
//  为什么不用 .usdz：本机是 Windows，做不了也验不了 3D 模型资产；
//  先用代码搭几何体，将来有真模型只需把 PetSceneBuilder.build 里换成 ModelEntity(named:)
//  未在本机编译验证，靠 GitHub Actions 的 macOS 模拟器编译 + 截图确认            // 验证说明

import RealityKit  // 3D 引擎
import SwiftUI  // 界面框架
import UIKit  // UIColor

// MARK: - 配色与尺寸                                                  // 分节：常量

enum CatPalette {  // 猫的固定用色（毛色不在这里，由配件表给）
    static let eye = UIColor(hex: "2B2B33")  // 眼睛：近黑
    static let eyeShine = UIColor(hex: "FFFFFF")  // 眼里的高光点
    static let nose = UIColor(hex: "F08A93")  // 鼻子：粉
    static let innerEar = UIColor(hex: "F7C6CC")  // 内耳：浅粉
    static let paw = UIColor(hex: "F7C6CC")  // 肉垫：粉
    static let whisker = UIColor(hex: "9AA3B2")  // 胡须：灰
    static let ground = UIColor(hex: "D9DEE8")  // 地台：浅灰
}  // CatPalette 结束

enum CatMetrics {  // 尺寸
    static let petScale: Float = 0.72  // 整只缩放
    static let bodyRadius: Float = 0.26  // 身体半径
    static let headRadius: Float = 0.24  // 头半径
    static let headY: Float = 0.66  // 头心高度
    static let tailName = "cat.tail"  // 尾巴节点名，动画按名字找
}  // CatMetrics 结束

// MARK: - 视图入口                                                    // 分节：入口

/// 3D 伙伴（猫）。jumpToken / flipToken / wagToken 每加 1 播一次动作
struct PetSceneView: UIViewRepresentable {  // 3D 视图
    let stage: PetStage  // 成长阶段，决定体型与帽子大小
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
            let base = pet.transform  // 记住当前位置（起伏动画改过它）
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
            up.translation.y += 0.025  // 抬 2.5 厘米
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

    /// 放一台固定相机：略高于猫、正前方 1.5 米
    static func installCamera(on view: ARView) {  // 装相机
        let camera = PerspectiveCamera()  // 相机实体
        camera.camera.fieldOfViewInDegrees = 45  // 视角
        let holder = AnchorEntity(world: [0, 0.60, 1.5])  // 相机位置
        holder.addChild(camera)  // 挂上相机
        view.scene.addAnchor(holder)  // 加入场景
    }  // installCamera 结束

    /// 搭一只坐姿的猫，朝 +Z 面向相机
    static func build(stage: PetStage, outfit: CatOutfit) -> Entity {  // 搭猫
        let root = Entity()  // 根节点
        root.name = "pet.root"  // 便于调试查找
        let bodyColor = furColor(outfit: outfit, accent: false)  // 毛色
        let bellyColor = furColor(outfit: outfit, accent: true)  // 肚皮色

        let body = sphere(radius: CatMetrics.bodyRadius, color: bodyColor)  // 身体
        body.position = [0, CatMetrics.bodyRadius, 0]  // 坐在地上
        body.scale = [1, 1.02, 0.94]  // 略压圆
        root.addChild(body)  // 挂上

        let chest = sphere(radius: 0.19, color: bellyColor)  // 胸前浅色
        chest.position = [0, 0.30, 0.10]  // 胸口偏前
        chest.scale = [1, 1.1, 0.7]  // 压成片
        root.addChild(chest)  // 挂上

        let head = sphere(radius: CatMetrics.headRadius, color: bodyColor)  // 头
        head.position = [0, CatMetrics.headY, 0]  // 身体上方
        head.scale = [1.05, 1, 0.98]  // 略宽，像猫脸
        root.addChild(head)  // 挂上

        root.addChild(ears(color: bodyColor))  // 两只尖耳
        root.addChild(faceParts())  // 眼睛鼻子胡须
        root.addChild(frontLegs(color: bodyColor))  // 前腿与爪子
        root.addChild(tail(color: bodyColor))  // 尾巴
        root.addChild(wearables(stage: stage, outfit: outfit))  // 可换的配件

        let ground = ModelEntity(mesh: .generateCylinder(height: 0.01, radius: 0.40),  // 地台
                                 materials: [material(CatPalette.ground)])  // 灰色
        ground.position = [0, 0.005, 0]  // 贴地
        root.addChild(ground)  // 挂上

        root.scale = [CatMetrics.petScale, CatMetrics.petScale, CatMetrics.petScale]  // 整体缩放
        return root  // 返回整只
    }  // build 结束

    // MARK: - 部件                                                  // 分节：部件

    static func ears(color: UIColor) -> Entity {  // 尖耳组
        let group = Entity()  // 耳朵整体
        for side in [-1.0, 1.0] {  // 左右各一
            let ear = sphere(radius: 0.085, color: color)  // 外耳
            ear.position = [Float(side) * 0.148, 0.855, -0.01]  // 头顶两侧
            ear.scale = [0.85, 1.55, 0.5]  // 拉长压扁成尖
            ear.orientation = simd_quatf(angle: Float(side) * 0.26, axis: [0, 0, 1])  // 向外倾
            group.addChild(ear)  // 挂上

            let inner = sphere(radius: 0.05, color: CatPalette.innerEar)  // 内耳
            inner.position = [Float(side) * 0.145, 0.845, 0.03]  // 稍前稍下
            inner.scale = [0.8, 1.4, 0.35]  // 比外耳小一圈
            inner.orientation = simd_quatf(angle: Float(side) * 0.26, axis: [0, 0, 1])  // 同角度
            group.addChild(inner)  // 挂上
        }  // 循环结束
        return group  // 返回耳朵组
    }  // ears 结束

    static func faceParts() -> Entity {  // 眼睛鼻子胡须
        let group = Entity()  // 面部整体
        for side in [-1.0, 1.0] {  // 左右各一
            let eye = sphere(radius: 0.045, color: CatPalette.eye)  // 眼睛
            eye.position = [Float(side) * 0.093, 0.685, 0.207]  // 脸前方
            group.addChild(eye)  // 挂上

            let shine = sphere(radius: 0.014, color: CatPalette.eyeShine)  // 高光点
            shine.position = [Float(side) * 0.108, 0.703, 0.24]  // 眼睛右上角
            group.addChild(shine)  // 挂上

            for i in 0..<3 {  // 每侧三根胡须
                let whisker = ModelEntity(mesh: .generateCylinder(height: 0.13, radius: 0.0035),  // 细杆
                                          materials: [material(CatPalette.whisker)])  // 灰色
                whisker.position = [Float(side) * 0.155, 0.638 + Float(i) * 0.022, 0.19]  // 嘴两侧
                whisker.orientation = simd_quatf(angle: .pi / 2, axis: [0, 0, 1])  // 转成横向
                whisker.orientation *= simd_quatf(angle: Float(side) * 0.24, axis: [0, 1, 0])  // 向外撇
                group.addChild(whisker)  // 挂上
            }  // 胡须循环结束
        }  // 循环结束

        let nose = sphere(radius: 0.028, color: CatPalette.nose)  // 鼻子
        nose.position = [0, 0.628, 0.233]  // 脸中央略下
        nose.scale = [1.2, 0.85, 0.8]  // 压成小三角的感觉
        group.addChild(nose)  // 挂上
        return group  // 返回面部组
    }  // faceParts 结束

    static func frontLegs(color: UIColor) -> Entity {  // 前腿与爪子
        let group = Entity()  // 腿组
        for side in [-1.0, 1.0] {  // 左右各一
            let leg = sphere(radius: 0.072, color: color)  // 前腿
            leg.position = [Float(side) * 0.105, 0.145, 0.155]  // 胸前下方
            leg.scale = [0.9, 1.9, 0.9]  // 拉长
            group.addChild(leg)  // 挂上

            let paw = sphere(radius: 0.062, color: color)  // 爪子
            paw.position = [Float(side) * 0.105, 0.048, 0.185]  // 落地
            paw.scale = [1, 0.62, 1.15]  // 压扁拉长
            group.addChild(paw)  // 挂上

            let pad = sphere(radius: 0.028, color: CatPalette.paw)  // 肉垫
            pad.position = [Float(side) * 0.105, 0.052, 0.235]  // 爪子前缘
            pad.scale = [1, 0.5, 0.8]  // 扁平
            group.addChild(pad)  // 挂上
        }  // 循环结束
        return group  // 返回腿组
    }  // frontLegs 结束

    static func tail(color: UIColor) -> Entity {  // 尾巴（绕到身前，坐姿猫常见）
        let pivot = Entity()  // 尾巴根部节点，摆动转它
        pivot.name = CatMetrics.tailName  // 起名方便查找
        pivot.position = [0.16, 0.09, -0.10]  // 身侧偏后
        var radius: Float = 0.055  // 起始粗细
        for i in 0..<6 {  // 六段串成弧线
            let seg = sphere(radius: radius, color: color)  // 一段
            let t = Float(i)  // 段序号
            seg.position = [0.02 * t, 0.012 * t * t, 0.055 + 0.05 * t]  // 向前上方卷
            pivot.addChild(seg)  // 挂上
            radius *= 0.86  // 越末端越细
        }  // 循环结束
        return pivot  // 返回尾巴根
    }  // tail 结束

    // MARK: - 配件                                                  // 分节：配件

    static func wearables(stage: PetStage, outfit: CatOutfit) -> Entity {  // 按穿戴装配件
        let group = Entity()  // 配件整体
        let hat = catalog.item(id: outfit.id(for: .hat) ?? "")  // 头顶配件
        if let hat, hat.id != "hat.none" {  // 不是「不戴」
            group.addChild(hatEntity(hat, stage: stage))  // 装帽子
        }  // 分支结束
        let face = catalog.item(id: outfit.id(for: .face) ?? "")  // 脸部配件
        if let face, face.id != "face.none" {  // 不是「不戴」
            group.addChild(glassesEntity(face))  // 装眼镜
        }  // 分支结束
        let neck = catalog.item(id: outfit.id(for: .neck) ?? "")  // 颈部配件
        if let neck, neck.id != "neck.none" {  // 不是「不戴」
            group.addChild(neckEntity(neck))  // 装围巾或项圈
        }  // 分支结束
        let back = catalog.item(id: outfit.id(for: .back) ?? "")  // 背部配件
        if let back, back.id != "back.none" {  // 不是「不戴」
            group.addChild(backEntity(back))  // 装背包或披风
        }  // 分支结束
        return group  // 返回配件组
    }  // wearables 结束

    static func hatEntity(_ item: OutfitItem, stage: PetStage) -> Entity {  // 帽子
        let group = Entity()  // 帽子整体
        group.position = [0, 0.845, 0]  // 头顶
        let main = UIColor(hex: item.hex)  // 主色
        let accent = UIColor(hex: item.accent)  // 点缀色

        if item.id == "hat.graduate" {  // 学士帽
            let crown = ModelEntity(mesh: .generateCylinder(height: 0.06, radius: 0.135),  // 帽围
                                    materials: [material(main)])  // 深色
            group.addChild(crown)  // 挂上
            let board = ModelEntity(mesh: .generateBox(width: 0.30, height: 0.016, depth: 0.30, cornerRadius: 0.004),  // 帽板
                                    materials: [material(main)])  // 深色
            board.position = [0, 0.04, 0]  // 帽围上方
            group.addChild(board)  // 挂上
            let ring = ModelEntity(mesh: .generateCylinder(height: 0.014, radius: 0.142),  // 金环
                                   materials: [material(accent, metallic: true)])  // 金属
            ring.position = [0, 0.018, 0]  // 帽围上沿
            group.addChild(ring)  // 挂上
            let tassel = Entity()  // 流苏节点
            tassel.name = tasselName  // 起名方便拨穗
            tassel.position = [0.15, 0.04, 0.05]  // 帽檐右前方
            let cord = ModelEntity(mesh: .generateCylinder(height: 0.11, radius: 0.005),  // 流苏绳
                                   materials: [material(UIColor(hex: "EF3B30"))])  // 红绳
            cord.position = [0, -0.055, 0]  // 绳在节点下方
            tassel.addChild(cord)  // 挂上
            let knot = sphere(radius: 0.026, color: UIColor(hex: "EF3B30"))  // 流苏头
            knot.position = [0, -0.115, 0]  // 绳末端
            tassel.addChild(knot)  // 挂上
            group.addChild(tassel)  // 挂到帽子
        } else if item.id == "hat.beanie" {  // 毛线帽
            let dome = sphere(radius: 0.15, color: main)  // 半球
            dome.scale = [1, 0.72, 1]  // 压扁
            dome.position = [0, 0.012, 0]  // 盖住头顶
            group.addChild(dome)  // 挂上
            let brim = ModelEntity(mesh: .generateCylinder(height: 0.035, radius: 0.152),  // 帽檐
                                   materials: [material(main)])  // 主色
            group.addChild(brim)  // 挂上
            let pom = sphere(radius: 0.055, color: accent)  // 绒球
            pom.position = [0, 0.135, 0]  // 顶部
            group.addChild(pom)  // 挂上
        } else if item.id == "hat.crown" {  // 小皇冠
            let band = ModelEntity(mesh: .generateCylinder(height: 0.045, radius: 0.13),  // 冠环
                                   materials: [material(main, metallic: true)])  // 金属
            group.addChild(band)  // 挂上
            for i in 0..<5 {  // 五个尖
                let angle = Float(i) * (2 * .pi / 5)  // 均分一圈
                let spike = sphere(radius: 0.03, color: main)  // 尖（用球拉长）
                spike.scale = [0.7, 2.0, 0.7]  // 拉高
                spike.position = [cos(angle) * 0.11, 0.055, sin(angle) * 0.11]  // 沿环排布
                group.addChild(spike)  // 挂上
            }  // 循环结束
            let gem = sphere(radius: 0.022, color: accent)  // 正中宝石
            gem.position = [0, 0.01, 0.132]  // 正面
            group.addChild(gem)  // 挂上
        } else if item.id == "hat.headphones" {  // 耳机
            let band = ModelEntity(mesh: .generateBox(width: 0.30, height: 0.028, depth: 0.035, cornerRadius: 0.012),  // 横梁
                                   materials: [material(main)])  // 深色
            band.position = [0, 0.06, 0]  // 头顶上方
            group.addChild(band)  // 挂上
            for side in [-1.0, 1.0] {  // 左右耳罩
                let cup = ModelEntity(mesh: .generateCylinder(height: 0.05, radius: 0.055),  // 耳罩
                                      materials: [material(main)])  // 深色
                cup.position = [Float(side) * 0.15, -0.03, 0]  // 两侧
                cup.orientation = simd_quatf(angle: .pi / 2, axis: [0, 0, 1])  // 横放
                group.addChild(cup)  // 挂上
                let glow = sphere(radius: 0.02, color: accent)  // 指示灯光
                glow.position = [Float(side) * 0.175, -0.03, 0.02]  // 耳罩外侧
                group.addChild(glow)  // 挂上
            }  // 循环结束
        }  // 分支结束

        if stage == .seed { group.scale = [0.88, 0.88, 0.88] }  // 幼体帽子小一号
        return group  // 返回帽子
    }  // hatEntity 结束

    static func glassesEntity(_ item: OutfitItem) -> Entity {  // 眼镜
        let group = Entity()  // 眼镜整体
        group.position = [0, 0.688, 0.205]  // 眼睛位置
        let frame = UIColor(hex: item.hex)  // 框色
        let lens = UIColor(hex: item.accent)  // 镜片色
        for side in [-1.0, 1.0] {  // 左右镜片
            let glass = ModelEntity(mesh: .generateCylinder(height: 0.012, radius: 0.062),  // 镜片盘
                                    materials: [material(lens)])  // 镜片色
            glass.position = [Float(side) * 0.093, 0, 0.03]  // 对应眼睛
            glass.orientation = simd_quatf(angle: .pi / 2, axis: [1, 0, 0])  // 立起来
            group.addChild(glass)  // 挂上
            let rim = ModelEntity(mesh: .generateCylinder(height: 0.008, radius: 0.070),  // 镜圈
                                  materials: [material(frame)])  // 框色
            rim.position = [Float(side) * 0.093, 0, 0.026]  // 镜片后一点
            rim.orientation = simd_quatf(angle: .pi / 2, axis: [1, 0, 0])  // 同镜片
            group.addChild(rim)  // 挂上
            let leg = ModelEntity(mesh: .generateCylinder(height: 0.11, radius: 0.005),  // 镜腿
                                  materials: [material(frame)])  // 框色
            leg.position = [Float(side) * 0.155, 0, -0.02]  // 往耳朵方向
            leg.orientation = simd_quatf(angle: .pi / 2, axis: [0, 1, 0])  // 横向
            group.addChild(leg)  // 挂上
        }  // 循环结束
        let bridge = ModelEntity(mesh: .generateBox(width: 0.07, height: 0.008, depth: 0.008),  // 鼻梁
                                 materials: [material(frame)])  // 框色
        bridge.position = [0, 0.01, 0.03]  // 两镜片之间
        group.addChild(bridge)  // 挂上
        return group  // 返回眼镜
    }  // glassesEntity 结束

    static func neckEntity(_ item: OutfitItem) -> Entity {  // 围巾或项圈
        let group = Entity()  // 颈部整体
        group.position = [0, 0.47, 0.02]  // 脖子位置
        let main = UIColor(hex: item.hex)  // 主色
        let accent = UIColor(hex: item.accent)  // 点缀色

        if item.id.hasPrefix("neck.scarf") {  // 围巾
            let band = ModelEntity(mesh: .generateCylinder(height: 0.055, radius: 0.175),  // 围一圈
                                   materials: [material(main)])  // 主色
            band.scale = [1, 1, 0.82]  // 前后压薄
            group.addChild(band)  // 挂上
            let hang = ModelEntity(mesh: .generateBox(width: 0.075, height: 0.16, depth: 0.02, cornerRadius: 0.008),  // 垂下一截
                                   materials: [material(main)])  // 主色
            hang.position = [0.06, -0.095, 0.145]  // 胸前
            hang.orientation = simd_quatf(angle: 0.16, axis: [0, 0, 1])  // 稍微歪
            group.addChild(hang)  // 挂上
            let tip = ModelEntity(mesh: .generateBox(width: 0.078, height: 0.022, depth: 0.022, cornerRadius: 0.006),  // 流苏边
                                  materials: [material(accent)])  // 点缀色
            tip.position = [0.075, -0.172, 0.145]  // 垂片末端
            group.addChild(tip)  // 挂上
        } else if item.id == "neck.bell" {  // 铃铛项圈
            let band = ModelEntity(mesh: .generateCylinder(height: 0.032, radius: 0.172),  // 项圈
                                   materials: [material(main)])  // 主色
            band.scale = [1, 1, 0.85]  // 压薄
            group.addChild(band)  // 挂上
            let bell = sphere(radius: 0.042, color: accent)  // 铃铛
            bell.position = [0, -0.03, 0.165]  // 脖子正前
            group.addChild(bell)  // 挂上
            let hole = sphere(radius: 0.012, color: main)  // 铃铛上的孔
            hole.position = [0, -0.045, 0.20]  // 铃铛下方
            group.addChild(hole)  // 挂上
        } else if item.id == "neck.bowtie" {  // 领结
            for side in [-1.0, 1.0] {  // 左右两片
                let wing = ModelEntity(mesh: .generateBox(width: 0.075, height: 0.055, depth: 0.022, cornerRadius: 0.01),  // 一片翅膀
                                       materials: [material(main)])  // 主色
                wing.position = [Float(side) * 0.055, 0, 0.16]  // 分列两侧
                wing.orientation = simd_quatf(angle: Float(side) * 0.35, axis: [0, 1, 0])  // 微微外张
                group.addChild(wing)  // 挂上
            }  // 循环结束
            let knot = ModelEntity(mesh: .generateBox(width: 0.03, height: 0.042, depth: 0.028, cornerRadius: 0.01),  // 结
                                   materials: [material(accent)])  // 点缀色
            knot.position = [0, 0, 0.168]  // 正中
            group.addChild(knot)  // 挂上
        }  // 分支结束
        return group  // 返回颈部配件
    }  // neckEntity 结束

    static func backEntity(_ item: OutfitItem) -> Entity {  // 背包或披风
        let group = Entity()  // 背部整体
        let main = UIColor(hex: item.hex)  // 主色
        let accent = UIColor(hex: item.accent)  // 点缀色

        if item.id == "back.backpack" {  // 小书包
            group.position = [0, 0.30, -0.21]  // 背后
            let bag = ModelEntity(mesh: .generateBox(width: 0.20, height: 0.20, depth: 0.11, cornerRadius: 0.03),  // 包体
                                  materials: [material(main)])  // 主色
            group.addChild(bag)  // 挂上
            let flap = ModelEntity(mesh: .generateBox(width: 0.19, height: 0.10, depth: 0.02, cornerRadius: 0.02),  // 翻盖
                                   materials: [material(accent)])  // 点缀色
            flap.position = [0, 0.055, -0.058]  // 背面顶部
            group.addChild(flap)  // 挂上
            for side in [-1.0, 1.0] {  // 两条肩带
                let strap = ModelEntity(mesh: .generateCylinder(height: 0.22, radius: 0.012),  // 带子
                                        materials: [material(accent)])  // 点缀色
                strap.position = [Float(side) * 0.09, 0.02, 0.07]  // 绕到胸前
                strap.orientation = simd_quatf(angle: 0.2, axis: [1, 0, 0])  // 略微前倾
                group.addChild(strap)  // 挂上
            }  // 循环结束
        } else if item.id == "back.cape" {  // 披风
            group.position = [0, 0.40, -0.16]  // 颈部后方
            let cloth = ModelEntity(mesh: .generateBox(width: 0.34, height: 0.40, depth: 0.014, cornerRadius: 0.02),  // 披风布
                                    materials: [material(main)])  // 主色
            cloth.position = [0, -0.16, 0]  // 向下垂
            cloth.orientation = simd_quatf(angle: -0.18, axis: [1, 0, 0])  // 后摆
            group.addChild(cloth)  // 挂上
            let clasp = sphere(radius: 0.035, color: accent)  // 领扣
            clasp.position = [0, 0.03, 0.03]  // 颈部
            group.addChild(clasp)  // 挂上
        }  // 分支结束
        return group  // 返回背部配件
    }  // backEntity 结束

    // MARK: - 小工具                                                // 分节：工具

    static func furColor(outfit: CatOutfit, accent: Bool) -> UIColor {  // 取毛色
        let id = outfit.id(for: .fur) ?? "fur.cream"  // 当前毛色 id
        let item = catalog.item(id: id)  // 查配件表
        let hex = accent ? (item?.accent ?? "FFFFFF") : (item?.hex ?? "F7EDE2")  // 按需要取主色或点缀色
        return UIColor(hex: hex)  // 转成颜色
    }  // furColor 结束

    static func sphere(radius: Float, color: UIColor) -> ModelEntity {  // 造一个球
        ModelEntity(mesh: .generateSphere(radius: radius), materials: [material(color)])  // 直接返回
    }  // sphere 结束

    static func material(_ color: UIColor, metallic: Bool = false) -> SimpleMaterial {  // 造一个材质
        SimpleMaterial(color: color, roughness: .float(0.62), isMetallic: metallic)  // 哑光为主，像毛绒
    }  // material 结束
}  // PetSceneBuilder 结束
