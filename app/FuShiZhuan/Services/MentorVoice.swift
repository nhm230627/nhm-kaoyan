//  MentorVoice.swift —— 导师播报（系统 TTS）                          // 文件说明
//  只做「把问题读出来」，不做录音、不做识别，和 SpeechService 互不干扰     // 职责约束
//  播报失败不影响面试继续，静音开关持久化在 UserDefaults                // 降级原则

import AVFoundation                                                  // 播报与音频会话
import Combine                                                       // ObservableObject
import Foundation                                                    // 基础库

/// 为什么用 ObservableObject 而不是 @Observable：
/// AVSpeechSynthesizerDelegate 要求继承 NSObject，NSObject + @Observable 的组合没有把握在真机编译通过，
/// 而 NSObject + ObservableObject + @Published 是十年验证过的写法。这里优先保证能编译。
final class MentorVoice: NSObject, ObservableObject, AVSpeechSynthesizerDelegate { // 导师播报器
    @Published private(set) var isSpeaking = false                     // 是否正在播
    @Published private(set) var isMuted = false                       // 是否静音

    private let synth = AVSpeechSynthesizer()                         // 合成器，全局一个
    private static let muteKey = "app.voice.muted"                    // 静音开关存储键

    override init() {                                                 // 构造器
        super.init()                                                  // 先完成父类构造，再碰 @Published
        isMuted = UserDefaults.standard.bool(forKey: Self.muteKey)    // 读上次的开关
        synth.delegate = self                                         // 接播报回调
    }                                                                 // 构造结束

    // MARK: - 对外                                                      // 分节：对外

    /// 播报一句话。静音、空文本、正在说的话都直接返回，绝不抛错
    func speak(_ text: String, as role: MentorRole) {                  // 播报
        let clean = text.trimmingCharacters(in: .whitespacesAndNewlines) // 去空白
        guard !isMuted, !clean.isEmpty else { return }                 // 静音或空就不播
        stop()                                                        // 有上一句先掐掉，避免叠音

        let session = AVAudioSession.sharedInstance()                 // 取音频会话
        try? session.setCategory(.playback, mode: .spokenAudio, options: .duckOthers) // 播报压低其它音
        try? session.setActive(true, options: .notifyOthersOnDeactivation) // 激活

        let utterance = AVSpeechUtterance(string: clean)              // 待读文本
        utterance.voice = AVSpeechSynthesisVoice(language: "zh-CN")   // 中文音色
        utterance.pitchMultiplier = role.voicePitch                   // 角色音高
        utterance.rate = role.voiceRate                               // 角色语速
        utterance.postUtteranceDelay = 0.1                            // 读完稍停
        isSpeaking = true                                             // 标记在播
        synth.speak(utterance)                                        // 开始读
    }                                                                 // speak 结束

    /// 停止播报并释放音频会话
    func stop() {                                                     // 停止
        if synth.isSpeaking { synth.stopSpeaking(at: .immediate) }     // 正在读才停
        isSpeaking = false                                            // 清标记
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation) // 让出音频
    }                                                                 // stop 结束

    /// 切换静音，静音时立即掐断当前播报
    func toggleMute() {                                               // 切换静音
        isMuted.toggle()                                              // 翻转
        UserDefaults.standard.set(isMuted, forKey: Self.muteKey)       // 记住选择
        if isMuted { stop() }                                         // 静音就立刻停
    }                                                                 // toggleMute 结束

    // MARK: - 回调                                                      // 分节：回调

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) { // 读完
        Task { @MainActor in self.isSpeaking = false }                // 回主线程清标记
    }                                                                 // 方法结束

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) { // 被取消
        Task { @MainActor in self.isSpeaking = false }                // 回主线程清标记
    }                                                                 // 方法结束
}                                                                    // MentorVoice 结束
