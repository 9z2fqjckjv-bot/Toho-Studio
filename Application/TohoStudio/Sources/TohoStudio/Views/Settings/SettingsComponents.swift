import SwiftUI

// MARK: - Keynote Style Return Arrow
public struct ReturnArrowButton: View {
    public var action: () -> Void

    public init(action: @escaping () -> Void) {
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Image(systemName: "arrow.uturn.backward")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(Color(red: 0.22, green: 0.58, blue: 0.88))
                .frame(width: 44, height: 44)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Keynote Column Selection Button
public struct KeynoteColumnButton: View {
    public let title: String
    public let isSelected: Bool
    public var isDanger: Bool = false
    public var action: () -> Void

    public init(title: String, isSelected: Bool, isDanger: Bool = false, action: @escaping () -> Void) {
        self.title = title
        self.isSelected = isSelected
        self.isDanger = isDanger
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: isSelected ? .bold : .medium))
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .foregroundColor(textColor)
                .padding(.horizontal, 10)
                .padding(.vertical, 12)
                .frame(maxWidth: .infinity)
                .frame(minHeight: 46)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(backgroundColor)
                        .shadow(color: isSelected ? Color.black.opacity(0.15) : Color.clear, radius: 2, y: 1)
                )
        }
        .buttonStyle(.plain)
    }

    private var backgroundColor: Color {
        if isDanger {
            return isSelected ? Color(red: 0.92, green: 0.35, blue: 0.45) : Color(red: 0.95, green: 0.65, blue: 0.75)
        }
        if isSelected {
            // Selected state in Keynote: Dark slate blue
            return Color(red: 0.12, green: 0.32, blue: 0.53)
        } else {
            // Unselected state in Keynote: Light blue/slate
            return Color(red: 0.55, green: 0.68, blue: 0.80)
        }
    }

    private var textColor: Color {
        return .white
    }
}

// MARK: - Keynote Annotation / Speech Bubble View
public struct KeynoteAnnotationBubble: View {
    public let text: String
    public var pointerDirection: PointerDirection = .left

    public enum PointerDirection {
        case left, right, top, bottom
    }

    public init(_ text: String, pointerDirection: PointerDirection = .left) {
        self.text = text
        self.pointerDirection = pointerDirection
    }

    public var body: some View {
        HStack(alignment: .top, spacing: 6) {
            if pointerDirection == .left {
                Image(systemName: "arrowtriangle.backward.fill")
                    .font(.caption2)
                    .foregroundColor(Color.black.opacity(0.85))
                    .padding(.top, 4)
            }
            Text(text)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white)
                .lineSpacing(2)
            if pointerDirection == .right {
                Image(systemName: "arrowtriangle.forward.fill")
                    .font(.caption2)
                    .foregroundColor(Color.black.opacity(0.85))
                    .padding(.top, 4)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.black.opacity(0.88))
        )
    }
}

// MARK: - Pie Chart Component
public struct SettingsPieChartView: View {
    public let items: [ProcessMemoryUsage]

    public init(items: [ProcessMemoryUsage]) {
        self.items = items
    }

    public var body: some View {
        GeometryReader { geo in
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let radius = min(geo.size.width, geo.size.height) / 2

            ZStack {
                ForEach(Array(segments().enumerated()), id: \.offset) { _, seg in
                    Path { path in
                        path.move(to: center)
                        path.addArc(
                            center: center,
                            radius: radius,
                            startAngle: seg.startAngle,
                            endAngle: seg.endAngle,
                            clockwise: false
                        )
                    }
                    .fill(seg.item.color)

                    // Percentage label
                    if seg.item.percentage >= 6.0 {
                        let midAngle = (seg.startAngle.radians + seg.endAngle.radians) / 2
                        let labelRadius = radius * 0.65
                        let labelX = center.x + CGFloat(cos(midAngle)) * labelRadius
                        let labelY = center.y + CGFloat(sin(midAngle)) * labelRadius
                        Text("\(Int(seg.item.percentage))%")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(.white)
                            .position(x: labelX, y: labelY)
                    }
                }
            }
        }
    }

    private struct Segment {
        let item: ProcessMemoryUsage
        let startAngle: Angle
        let endAngle: Angle
    }

    private func segments() -> [Segment] {
        var result: [Segment] = []
        var currentAngle = Angle(degrees: -90)
        for item in items {
            let sweep = Angle(degrees: item.percentage * 3.6)
            result.append(Segment(item: item, startAngle: currentAngle, endAngle: currentAngle + sweep))
            currentAngle += sweep
        }
        return result
    }
}

// MARK: - Bar Chart Component
public struct SettingsBarChartView: View {
    public let items: [ProcessMemoryUsage]
    public var maxVal: Double = 2.0

    public init(items: [ProcessMemoryUsage], maxVal: Double = 2.0) {
        self.items = items
        self.maxVal = maxVal
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(items) { item in
                HStack(spacing: 8) {
                    Text(item.processName)
                        .font(.system(size: 10))
                        .frame(width: 80, alignment: .trailing)
                    GeometryReader { g in
                        let w = g.size.width * CGFloat(min(item.memoryGB / maxVal, 1.0))
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color(red: 0.3, green: 0.65, blue: 0.95))
                            .frame(width: max(w, 2), height: 14)
                    }
                    .frame(height: 14)
                    Text(String(format: "%.1fGB", item.memoryGB))
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                        .frame(width: 38, alignment: .leading)
                }
            }
        }
    }
}
