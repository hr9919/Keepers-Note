//
//  CropTimerLiveActivity.swift
//  CropTimerLiveActivity
//

import ActivityKit
import WidgetKit
import SwiftUI

struct LiveActivitiesAppAttributes: ActivityAttributes, Identifiable {
    public typealias LiveDeliveryData = ContentState

    public struct ContentState: Codable, Hashable {
    }

    var id = UUID()
}

extension LiveActivitiesAppAttributes {
    func prefixedKey(_ key: String) -> String {
        return "\(id)_\(key)"
    }
}

struct CropTimerLiveActivity: Widget {
    let sharedDefault = UserDefaults(suiteName: "group.com.townhelpers.keepersnote")!

    var body: some WidgetConfiguration {
        ActivityConfiguration(for: LiveActivitiesAppAttributes.self) { context in
            let cropName = sharedDefault.string(
                forKey: context.attributes.prefixedKey("cropName")
            ) ?? "작물"

            let cropId = sharedDefault.string(
                forKey: context.attributes.prefixedKey("cropId")
            ) ?? ""

            let summaryText = sharedDefault.string(
                forKey: context.attributes.prefixedKey("summaryText")
            ) ?? ""

            let plantedAtMillis = sharedDefault.double(
                forKey: context.attributes.prefixedKey("plantedAtMillis")
            )

            let harvestAtMillis = sharedDefault.double(
                forKey: context.attributes.prefixedKey("harvestAtMillis")
            )

            let plantedAt = plantedAtMillis > 0
                ? Date(timeIntervalSince1970: plantedAtMillis / 1000)
                : Date()

            let harvestAt = harvestAtMillis > 0
                ? Date(timeIntervalSince1970: harvestAtMillis / 1000)
                : Date().addingTimeInterval(60 * 15)

            CropTimerLockScreenView(
                cropId: cropId,
                cropName: cropName,
                summaryText: summaryText,
                plantedAt: plantedAt,
                harvestAt: harvestAt
            )
            .activityBackgroundTint(Color(red: 1.0, green: 0.94, blue: 0.91))
            .activitySystemActionForegroundColor(Color(red: 1.0, green: 0.56, blue: 0.49))
            .widgetURL(URL(string: "keepersnote://crop-timer?target=crop_timer"))

        } dynamicIsland: { context in
            let cropName = sharedDefault.string(
                forKey: context.attributes.prefixedKey("cropName")
            ) ?? "작물"

            let summaryText = sharedDefault.string(
                forKey: context.attributes.prefixedKey("summaryText")
            ) ?? ""

            let plantedAtMillis = sharedDefault.double(
                forKey: context.attributes.prefixedKey("plantedAtMillis")
            )

            let harvestAtMillis = sharedDefault.double(
                forKey: context.attributes.prefixedKey("harvestAtMillis")
            )

            let plantedAt = plantedAtMillis > 0
                ? Date(timeIntervalSince1970: plantedAtMillis / 1000)
                : Date()

            let harvestAt = harvestAtMillis > 0
                ? Date(timeIntervalSince1970: harvestAtMillis / 1000)
                : Date().addingTimeInterval(60 * 15)

            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 4) {
                       Text(summaryText.isEmpty ? "작물" : summaryText)
                            .font(.caption2)
                            .foregroundStyle(.secondary)

                        Text(cropName)
                            .font(.headline)
                            .fontWeight(.bold)
                            .lineLimit(1)
                    }
                }

                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("남은 시간")
                            .font(.caption2)
                            .foregroundStyle(.secondary)

                        CropTimerCountdownText(
                            harvestAt: harvestAt,
                            fontSize: 16
                        )
                    }
                }

                DynamicIslandExpandedRegion(.bottom) {
                    CropTimerProgressBar(
                        plantedAt: plantedAt,
                        harvestAt: harvestAt
                    )
                    .frame(height: 8)
                    .padding(.top, 4)
                }

            } compactLeading: {
                Image(systemName: "leaf.fill")
                    .foregroundStyle(Color(red: 1.0, green: 0.56, blue: 0.49))

                        } compactTrailing: {
                            CropTimerCountdownText(
                                harvestAt: harvestAt,
                                fontSize: 12
                            )

                        } minimal: {
                            Image(systemName: "leaf.fill")
                                .foregroundStyle(Color(red: 1.0, green: 0.56, blue: 0.49))
                        }
                        .widgetURL(URL(string: "keepersnote://crop-timer?target=crop_timer"))
                    }
    }
}

struct CropTimerLockScreenView: View {
    let cropId: String
    let cropName: String
    let summaryText: String
    let plantedAt: Date
    let harvestAt: Date

    private var cropAssetName: String {
        switch cropId {
        case "tomato":
            return "crop_tomato"
        case "potato":
            return "crop_potato"
        case "wheat":
            return "crop_wheat"
        case "lettuce":
            return "crop_lettuce"
        case "pineapple":
            return "crop_pineapple"
        case "carrot":
            return "crop_carrot"
        case "strawberry":
            return "crop_strawberry"
        case "corn":
            return "crop_corn"
        case "grape":
            return "crop_grape"
        case "eggplant":
            return "crop_eggplant"
        default:
            return "crop_tomato"
        }
    }

    var body: some View {
        HStack(spacing: 13) {
            ZStack {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.92),
                                Color(red: 1.0, green: 0.94, blue: 0.91)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Image(cropAssetName)
                    .resizable()
                    .scaledToFit()
                    .padding(11)
            }
            .frame(width: 64, height: 64)
            .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 4)

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .center, spacing: 10) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(cropName)
                            .font(.system(size: 18, weight: .heavy, design: .rounded))
                            .foregroundStyle(Color(red: 0.17, green: 0.19, blue: 0.22))
                            .lineLimit(1)

                        Text(summaryText.isEmpty ? "수확까지" : summaryText)
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(Color(red: 0.72, green: 0.76, blue: 0.82))
                            .lineLimit(1)
                    }

                    Spacer(minLength: 12)

                    CropTimerCountdownText(
                        harvestAt: harvestAt,
                        fontSize: 23
                    )
                    .frame(minWidth: 92, alignment: .trailing)
                }

                CropTimerProgressBar(
                    plantedAt: plantedAt,
                    harvestAt: harvestAt
                )
                .frame(height: 10)
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 1.0, green: 0.98, blue: 0.96),
                            Color(red: 1.0, green: 0.93, blue: 0.90)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
    }
}

struct CropTimerProgressBar: View {
    let plantedAt: Date
    let harvestAt: Date

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { timeline in
            let progress = calculateProgress(now: timeline.date)

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color(red: 1.0, green: 0.79, blue: 0.75).opacity(0.72))

                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 1.0, green: 0.53, blue: 0.47),
                                    Color(red: 1.0, green: 0.36, blue: 0.32)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(8, geometry.size.width * progress))
                }
            }
        }
    }

    private func calculateProgress(now: Date) -> Double {
        let total = harvestAt.timeIntervalSince(plantedAt)

        if total <= 0 {
            return 1.0
        }

        let passed = now.timeIntervalSince(plantedAt)
        return min(max(passed / total, 0.0), 1.0)
    }
}

struct CropTimerCountdownText: View {
    let harvestAt: Date
    let fontSize: CGFloat

    var body: some View {
        Text(timerInterval: Date()...harvestAt, countsDown: true)
            .font(.system(size: fontSize, weight: .heavy, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(Color(red: 1.0, green: 0.38, blue: 0.34))
            .lineLimit(1)
            .minimumScaleFactor(0.72)
            .multilineTextAlignment(.trailing)
    }
}