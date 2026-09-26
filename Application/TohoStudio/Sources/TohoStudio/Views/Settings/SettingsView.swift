import SwiftUI

public struct SettingsView: View {
    @ObservedObject var appState = AppState.shared
    @State private var selectedCategory: SettingsCategory = .account

    public init() {}

    public var body: some View {
        HStack(spacing: 0) {
            // MARK: - Column 1: Keynote Control Bar (Slides 38-144)
            controlBarColumn
                .frame(width: 100)
                .background(Color(red: 0.16, green: 0.22, blue: 0.30))

            Divider()

            // MARK: - Column 2: 11 Categories Selector (Slides 38-144)
            categoriesColumn
                .frame(width: 175)
                .background(Color(red: 0.84, green: 0.89, blue: 0.94))

            Divider()

            // MARK: - Category Detail Area (Columns 3, 4, 5 / Main Area)
            categoryDetailArea
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(red: 0.96, green: 0.97, blue: 0.99))
        }
        .frame(minWidth: 980, idealWidth: 1080, maxWidth: .infinity, minHeight: 640, idealHeight: 700, maxHeight: .infinity)
        .background(Color(NSColor.windowBackgroundColor))
        .cornerRadius(10)
        .shadow(color: Color.black.opacity(0.35), radius: 18, x: 0, y: 8)
    }

    // MARK: - Column 1: Control Bar View
    private var controlBarColumn: some View {
        VStack(spacing: 12) {
            // Return Button
            ReturnArrowButton {
                appState.activeModal = nil
            }
            .padding(.top, 12)

            Text("コントロールバー")
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(.white.opacity(0.7))

            Divider().background(Color.white.opacity(0.2))

            // 5 Control Bar Actions
            controlBarButton(title: "アプリ情報", isSelected: false) {
                appState.activeModal = .appInfo
            }

            controlBarButton(title: "設定", isSelected: true) {
                // Already in settings
            }

            controlBarButton(title: "ストア", isSelected: false) {
                appState.activeModal = .store
            }

            controlBarButton(title: "再起動", isSelected: false) {
                appState.activeModal = .reboot
            }

            controlBarButton(title: "開発者", isSelected: false) {
                appState.activeModal = .developer
            }

            Spacer()
        }
        .padding(.horizontal, 6)
    }

    private func controlBarButton(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 11, weight: isSelected ? .bold : .medium))
                .multilineTextAlignment(.center)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isSelected ? Color(red: 0.12, green: 0.45, blue: 0.75) : Color.white.opacity(0.12))
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Column 2: Categories Column
    private var categoriesColumn: some View {
        ScrollView {
            VStack(spacing: 6) {
                ForEach(SettingsCategory.allCases) { cat in
                    KeynoteColumnButton(
                        title: cat.rawValue,
                        isSelected: selectedCategory == cat,
                        isDanger: cat == .initialization
                    ) {
                        selectedCategory = cat
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 12)
        }
    }

    // MARK: - Dynamic Category Detail Area
    @ViewBuilder
    private var categoryDetailArea: some View {
        switch selectedCategory {
        case .account:
            AccountSettingsDetailView(activeCategory: $selectedCategory)
        case .policy:
            PolicySettingsDetailView()
        case .billingAndUsage:
            BillingUsageDetailView()
        case .storageAndPerf:
            StoragePerfDetailView()
        case .cloud:
            CloudSettingsDetailView()
        case .paidFeatures:
            PaidFeaturesDetailView()
        case .languageAndArea:
            LanguageRegionDetailView()
        case .legalAndCompliance:
            LegalComplianceDetailView()
        case .publishingDefaults:
            PublishingDefaultsDetailView()
        case .licenseAndAuth:
            LicenseAuthDetailView()
        case .initialization:
            InitializationDetailView()
        }
    }
}
