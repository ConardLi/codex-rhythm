import AppKit
import SwiftUI

struct ControlCenterView: View {
    @ObservedObject var model: ControlCenterViewModel
    @State private var isShowingTimePrediction = false

    var body: some View {
        ZStack {
            VisualEffectBlur(material: .underWindowBackground, blendingMode: .behindWindow)
                .ignoresSafeArea()
            Color.white.opacity(0.58).ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    header
                    usageCard
                    timerAssistantCard
                    footer
                }
                .padding(18)
            }
        }
        .frame(width: 420, height: 700)
        .preferredColorScheme(.light)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.78), lineWidth: 0.8)
        )
    }

    private var header: some View {
        HStack(spacing: 11) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.black.opacity(0.82))
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text("Codex Rhythm")
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                Text("额度与计时助手")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            HeaderButton(
                icon: model.isRefreshing ? "arrow.triangle.2.circlepath" : "arrow.clockwise",
                help: "同步额度",
                disabled: model.isRefreshing,
                action: model.onRefresh
            )
            HeaderButton(icon: "xmark", help: "关闭", action: model.onClose)
        }
    }

    private var usageCard: some View {
        PanelCard {
            VStack(spacing: 10) {
                HStack(spacing: 17) {
                    ZStack {
                        Circle()
                            .stroke(Color.black.opacity(0.07), lineWidth: 9)
                        Circle()
                            .trim(from: 0, to: CGFloat(model.fiveHourRemaining ?? 0) / 100)
                            .stroke(quotaColor, style: StrokeStyle(lineWidth: 9, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                        VStack(spacing: -1) {
                            Text(model.fiveHourRemaining.map(String.init) ?? "—")
                                .font(.system(size: 29, weight: .semibold, design: .rounded))
                            Text("% 剩余")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(width: 82, height: 82)

                    VStack(alignment: .leading, spacing: 7) {
                        HStack(spacing: 8) {
                            Text("5 小时额度")
                                .font(.system(size: 19, weight: .semibold, design: .rounded))
                            Spacer(minLength: 4)
                            Button {
                                isShowingTimePrediction.toggle()
                            } label: {
                                Label("时间预测", systemImage: "clock.badge.questionmark")
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundStyle(Color(red: 0.30, green: 0.40, blue: 0.24))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 5)
                                    .background(Color.green.opacity(0.09), in: Capsule())
                                    .overlay(Capsule().stroke(Color.green.opacity(0.20), lineWidth: 0.7))
                            }
                            .buttonStyle(.plain)
                            .help("查看未来三次预计重置时间")
                            .popover(isPresented: $isShowingTimePrediction, arrowEdge: .top) {
                                TimePredictionPopover(dates: model.predictedResetDates)
                            }
                        }
                        Label(model.resetText, systemImage: "clock")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)
                        HStack(spacing: 7) {
                            SmallTag(text: model.snapshot?.planType?.capitalized ?? "Codex", icon: "sparkles")
                            if model.bankedCount > 0 {
                                Button(action: model.onRedeemReset) {
                                    HStack(spacing: 4) {
                                        if model.isRedeemingReset {
                                            ProgressView().controlSize(.mini)
                                        } else {
                                            Image(systemName: "arrow.counterclockwise")
                                        }
                                        Text(model.isRedeemingReset ? "正在重置" : "立即重置 · \(model.bankedCount)")
                                    }
                                    .font(.system(size: 9, weight: .semibold))
                                    .foregroundStyle(Color(red: 0.25, green: 0.38, blue: 0.19))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 5)
                                    .background(Color.green.opacity(0.10), in: Capsule())
                                    .overlay(Capsule().stroke(Color.green.opacity(0.22), lineWidth: 0.7))
                                }
                                .buttonStyle(.plain)
                                .disabled(model.isRedeemingReset)
                                .help("手动使用一次限额重置")
                            }
                        }
                    }
                    Spacer(minLength: 0)
                }

                Divider().overlay(Color.black.opacity(0.06))

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("一周额度")
                            .font(.system(size: 12, weight: .medium))
                        Spacer()
                        Text("\(model.weeklyRemaining.map(String.init) ?? "—")% 剩余")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                        Text("· \(model.weeklyResetText)")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                    ProgressView(value: Double(model.weeklyRemaining ?? 0), total: 100)
                        .tint(Color(red: 0.39, green: 0.52, blue: 0.31))
                }

            }
        }
    }

    private var timerAssistantCard: some View {
        PanelCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 11) {
                    Image(systemName: "clock.badge.checkmark")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color(red: 0.32, green: 0.43, blue: 0.25))
                        .frame(width: 36, height: 36)
                        .background(Color.green.opacity(0.10), in: RoundedRectangle(cornerRadius: 11))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("计时助手")
                            .font(.system(size: 17, weight: .semibold, design: .rounded))
                        Text("让 5 小时重置倒计时先走起来")
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Toggle(
                        "",
                        isOn: Binding(
                            get: { model.isAssistantEnabled },
                            set: { model.onSetEnabled($0) }
                        )
                    )
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .tint(Color(red: 0.39, green: 0.52, blue: 0.31))
                }

                statusPanel

                HStack(spacing: 9) {
                    ModeChoice(
                        mode: .periodic,
                        selected: model.selectedMode == .periodic,
                        action: { model.onSelectMode(.periodic) }
                    )
                    ModeChoice(
                        mode: .fixedTime,
                        selected: model.selectedMode == .fixedTime,
                        action: { model.onSelectMode(.fixedTime) }
                    )
                }
                .disabled(!model.isAssistantEnabled)

                if model.selectedMode == .periodic {
                    periodicSettings
                } else {
                    fixedTimeSettings
                }

                HStack(alignment: .top, spacing: 7) {
                    Image(systemName: "checkmark.shield")
                        .foregroundStyle(Color(red: 0.36, green: 0.49, blue: 0.28))
                    Text("只有当前没有 5 小时计时时，才发送一次最小请求；正在计时时不会重复触发。")
                        .foregroundStyle(.secondary)
                }
                .font(.system(size: 10))

                if let notice = model.notice {
                    NoticeRow(text: notice, isError: model.noticeIsError)
                }

                Button(action: model.onManualRun) {
                    HStack {
                        if model.isRunningRequest {
                            ProgressView().controlSize(.small)
                        }
                        Text(model.isRunningRequest ? model.assistantStatusTitle : "手动启动计时")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 38)
                    .background(Color.black.opacity(0.84), in: RoundedRectangle(cornerRadius: 11))
                }
                .buttonStyle(.plain)
                .disabled(model.isRunningRequest)
                .opacity(model.isRunningRequest ? 0.6 : 1)
            }
        }
    }

    private var statusPanel: some View {
        HStack(alignment: .top, spacing: 10) {
            Circle()
                .fill(model.isAssistantEnabled ? Color.green : Color.gray)
                .frame(width: 8, height: 8)
                .padding(.top, 4)
            VStack(alignment: .leading, spacing: 3) {
                Text(model.assistantStatusTitle)
                    .font(.system(size: 12, weight: .semibold))
                Text(model.assistantStatusDetail)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
        .padding(10)
        .background(Color.green.opacity(model.isAssistantEnabled ? 0.07 : 0.025), in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.black.opacity(0.05), lineWidth: 0.7)
        )
    }

    private var periodicSettings: some View {
        VStack(spacing: 0) {
            SettingRow(title: "使用时段") {
                HStack(spacing: 5) {
                    TimePicker(date: Binding(
                        get: { model.activeStartDate },
                        set: {
                            model.activeStartDate = $0
                            model.onSettingsChanged()
                        }
                    ))
                    Text("至").font(.system(size: 10)).foregroundStyle(.secondary)
                    TimePicker(date: Binding(
                        get: { model.activeEndDate },
                        set: {
                            model.activeEndDate = $0
                            model.onSettingsChanged()
                        }
                    ))
                }
            }
            Divider().overlay(Color.black.opacity(0.05))
            SettingRow(title: "检查间隔") {
                Picker("", selection: Binding(
                    get: { model.checkIntervalMinutes },
                    set: {
                        model.checkIntervalMinutes = $0
                        model.onSettingsChanged()
                    }
                )) {
                    ForEach([5, 10, 15, 30], id: \.self) { minutes in
                        Text("每 \(minutes) 分钟").tag(minutes)
                    }
                }
                .labelsHidden()
                .frame(width: 112)
            }
        }
        .settingsSurface()
        .disabled(!model.isAssistantEnabled)
        .opacity(model.isAssistantEnabled ? 1 : 0.48)
    }

    private var fixedTimeSettings: some View {
        VStack(spacing: 0) {
            SettingRow(title: "每天检查") {
                TimePicker(date: Binding(
                    get: { model.fixedTimeOneDate },
                    set: {
                        model.fixedTimeOneDate = $0
                        model.onSettingsChanged()
                    }
                ))
            }
            if model.hasSecondFixedTime {
                Divider().overlay(Color.black.opacity(0.05))
                SettingRow(title: "再次检查") {
                    HStack(spacing: 6) {
                        TimePicker(date: Binding(
                            get: { model.fixedTimeTwoDate },
                            set: {
                                model.fixedTimeTwoDate = $0
                                model.onSettingsChanged()
                            }
                        ))
                        Button {
                            model.hasSecondFixedTime = false
                            model.onSettingsChanged()
                        } label: {
                            Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            } else {
                Divider().overlay(Color.black.opacity(0.05))
                Button {
                    model.hasSecondFixedTime = true
                    model.onSettingsChanged()
                } label: {
                    Label("添加一个时间", systemImage: "plus")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color(red: 0.34, green: 0.45, blue: 0.27))
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .frame(height: 38)
                }
                .buttonStyle(.plain)
            }
        }
        .settingsSurface()
        .disabled(!model.isAssistantEnabled)
        .opacity(model.isAssistantEnabled ? 1 : 0.48)
    }

    private var footer: some View {
        HStack {
            Button("打开 Codex", action: model.onOpenCodex)
            Spacer()
            Button("退出", action: model.onQuit)
        }
        .buttonStyle(.plain)
        .font(.system(size: 10, weight: .medium))
        .foregroundStyle(.secondary)
        .padding(.horizontal, 4)
    }

    private var quotaColor: Color {
        guard let remaining = model.fiveHourRemaining else { return .gray }
        if remaining <= 30 { return .red }
        if remaining <= 50 { return .orange }
        return Color(red: 0.39, green: 0.52, blue: 0.31)
    }
}
