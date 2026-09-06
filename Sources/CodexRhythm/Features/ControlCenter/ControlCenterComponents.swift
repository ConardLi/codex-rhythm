import AppKit
import SwiftUI

struct PanelCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.white.opacity(0.75), lineWidth: 0.8)
            )
            .shadow(color: Color.black.opacity(0.08), radius: 18, y: 8)
    }
}

struct HeaderButton: View {
    let icon: String
    let help: String
    var disabled = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .frame(width: 30, height: 30)
                .background(.regularMaterial, in: Circle())
                .overlay(Circle().stroke(Color.white.opacity(0.7), lineWidth: 0.7))
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .help(help)
    }
}

struct SmallTag: View {
    let text: String
    let icon: String

    var body: some View {
        Label(text, systemImage: icon)
            .font(.system(size: 9, weight: .medium))
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(Color.black.opacity(0.045), in: Capsule())
            .foregroundStyle(.secondary)
    }
}

struct TimePredictionPopover: View {
    let dates: [Date]

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            VStack(alignment: .leading, spacing: 3) {
                Text("未来三次重置")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                Text("按每轮恢复后及时启动下一轮推算")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }

            if dates.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "clock.badge.exclamationmark")
                        .foregroundStyle(.secondary)
                    Text("当前尚未开始计时，启动后即可预测")
                        .font(.system(size: 11, weight: .medium))
                }
                .padding(.vertical, 8)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(dates.enumerated()), id: \.offset) { index, date in
                        HStack(spacing: 11) {
                            Text("\(index + 1)")
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                                .foregroundStyle(Color(red: 0.31, green: 0.43, blue: 0.24))
                                .frame(width: 24, height: 24)
                                .background(Color.green.opacity(0.10), in: Circle())
                            VStack(alignment: .leading, spacing: 2) {
                                Text(dayText(for: date))
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary)
                                Text(timeText(for: date))
                                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                            }
                            Spacer()
                        }
                        .padding(.vertical, 8)
                        if index < dates.count - 1 {
                            Divider().overlay(Color.black.opacity(0.05))
                        }
                    }
                }
                .padding(.horizontal, 10)
                .background(Color.black.opacity(0.025), in: RoundedRectangle(cornerRadius: 12))
            }

            Text("电脑休眠、断网或未及时启动下一轮时，实际时间会顺延。")
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(width: 270)
        .background(.regularMaterial)
        .preferredColorScheme(.light)
    }

    private func dayText(for date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "今天" }
        if calendar.isDateInTomorrow(date) { return "明天" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M 月 d 日 EEE"
        return formatter.string(from: date)
    }

    private func timeText(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}

struct ModeChoice: View {
    let mode: TimerAssistantMode
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 5) {
                    Image(systemName: mode == .periodic ? "clock.arrow.2.circlepath" : "calendar.badge.clock")
                    Text(mode.displayName)
                        .font(.system(size: 12, weight: .semibold))
                    if mode == .periodic {
                        Text("推荐")
                            .font(.system(size: 8, weight: .medium))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.green.opacity(0.12), in: Capsule())
                    }
                }
                Text(mode == .periodic ? "使用时段内定期检查" : "每天到点检查一次")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(9)
            .background(
                selected ? Color.green.opacity(0.08) : Color.white.opacity(0.28),
                in: RoundedRectangle(cornerRadius: 11)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 11)
                    .stroke(selected ? Color.green.opacity(0.5) : Color.black.opacity(0.06), lineWidth: 0.8)
            )
        }
        .buttonStyle(.plain)
    }
}

struct SettingRow<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        HStack(spacing: 10) {
            Text(title)
                .font(.system(size: 11, weight: .medium))
            Spacer()
            content
        }
        .frame(minHeight: 38)
        .padding(.horizontal, 11)
    }
}

struct TimePicker: View {
    @Binding var date: Date

    var body: some View {
        DatePicker("", selection: $date, displayedComponents: .hourAndMinute)
            .labelsHidden()
            .datePickerStyle(.field)
            .frame(width: 78)
    }
}

struct NoticeRow: View {
    let text: String
    let isError: Bool

    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: isError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
            Text(text).lineLimit(2)
        }
        .font(.system(size: 10, weight: .medium))
        .foregroundStyle(isError ? Color.orange : Color(red: 0.32, green: 0.45, blue: 0.24))
        .padding(9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background((isError ? Color.orange : Color.green).opacity(0.08), in: RoundedRectangle(cornerRadius: 9))
    }
}

extension View {
    func settingsSurface() -> some View {
        background(Color.white.opacity(0.32), in: RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.black.opacity(0.055), lineWidth: 0.7)
            )
    }
}

struct VisualEffectBlur: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
    }
}
