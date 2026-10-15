import RevenueCat
import SwiftUI

private struct PremiumFeature {
    let icon: String
    let title: String
    let subtitle: String
}

struct PaywallView: View {
    var source: Analytics.PaywallSource = .manual

    @Environment(\.dismiss) private var dismiss
    @Environment(AuthState.self) private var authState
    @State private var offering: Offering?
    @State private var isPurchasing = false
    @State private var errorMessage: String?
    @State private var isRestoring = false
    @State private var didConvert = false
    @State private var isLoadingOffering = true

    private let termsURL = URL(string: "https://blnd.movie/terms")!
    private let privacyURL = URL(string: "https://blnd.movie/privacy")!

    private let features: [PremiumFeature] = [
        PremiumFeature(
            icon: "sparkles",
            title: "AI-Powered Search",
            subtitle: "Find movies by describing what you're in the mood for"
        ),
        PremiumFeature(
            icon: "person.3.fill",
            title: "Larger Groups",
            subtitle: "Create blends with up to 12 friends"
        ),
        PremiumFeature(
            icon: "star.fill",
            title: "Early Access",
            subtitle: "Be the first to try new features"
        ),
    ]

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 32) {
                    header
                    featureList
                    subscriptionSummary
                    legalSection
                    purchaseActions
                    restoreButton
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 40)
            }
        }
        .task {
            Analytics.paywallShown(source: source)
            await loadOffering()
        }
        .onDisappear {
            if !didConvert {
                Analytics.paywallDismissed(source: source)
            }
        }
        .alert("Error", isPresented: .constant(errorMessage != nil)) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 16) {
            HStack {
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(AppTheme.textMuted)
                        .frame(width: 32, height: 32)
                        .background(AppTheme.card)
                        .clipShape(Circle())
                }
            }

            BlndPlusBadge(size: 32)
                .padding(.top, 8)

            Text("Unlock the full experience")
                .font(.system(size: 16))
                .foregroundStyle(AppTheme.textMuted)
        }
    }

    // MARK: - Features

    private var featureList: some View {
        VStack(spacing: 0) {
            ForEach(Array(features.enumerated()), id: \.offset) { index, _ in
                let feature = features[index]
                HStack(spacing: 16) {
                    Image(systemName: feature.icon)
                        .font(.system(size: 18))
                        .foregroundStyle(AppTheme.premiumGradient)
                        .frame(width: 36, height: 36)
                        .background(AppTheme.card)
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusSmall))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(feature.title)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                        Text(feature.subtitle)
                            .font(.system(size: 13))
                            .foregroundStyle(AppTheme.textMuted)
                    }
                    Spacer()
                }
                .padding(.vertical, 14)
            }
        }
        .padding(.horizontal, 16)
        .background(AppTheme.card)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge))
    }

    // MARK: - Purchase

    /// Every auto-renewing package in the current offering, not only `.monthly`.
    /// A package RevenueCat doesn't tag as monthly still has to show its price.
    private var subscriptionPackages: [Package] {
        guard let offering else { return [] }
        let packages = offering.availablePackages
        let recurring = packages.filter { $0.storeProduct.subscriptionPeriod != nil }
        return recurring.isEmpty ? packages : recurring
    }

    @ViewBuilder
    private var subscriptionSummary: some View {
        if isLoadingOffering {
            ProgressView()
                .tint(.white)
                .padding(.vertical, 28)
        } else if subscriptionPackages.isEmpty {
            unavailableSection
        } else {
            VStack(spacing: 16) {
                ForEach(subscriptionPackages, id: \.storeProduct.productIdentifier) { package in
                    priceBlock(package)
                }
            }
        }
    }

    @ViewBuilder
    private var purchaseActions: some View {
        if !isLoadingOffering, !subscriptionPackages.isEmpty {
            VStack(spacing: 10) {
                ForEach(subscriptionPackages, id: \.storeProduct.productIdentifier) { package in
                    subscribeButton(package)
                }
            }
        }
    }

    private func priceBlock(_ package: Package) -> some View {
        VStack(spacing: 4) {
            Text(subscriptionTitle(package))
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
            Text(pricePhrase(package))
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    private var unavailableSection: some View {
        VStack(spacing: 12) {
            Text("Subscription options are temporarily unavailable. Please try again later.")
                .font(.system(size: 13))
                .foregroundStyle(AppTheme.textMuted)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

            Button {
                Task { await loadOffering() }
            } label: {
                Text("Try Again")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(AppTheme.card)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium))
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity)
        .background(AppTheme.card.opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusLarge))
    }

    private func subscribeButton(_ package: Package) -> some View {
        Button {
            Task { await purchase(package: package) }
        } label: {
            Group {
                if isPurchasing {
                    ProgressView()
                        .tint(.black)
                } else {
                    Text("Subscribe for \(pricePhrase(package))")
                        .font(.system(size: 17, weight: .bold))
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(AppTheme.premiumGradient)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.cornerRadiusMedium))
            .foregroundStyle(.black)
        }
        .disabled(isPurchasing)
    }

    private func pricePhrase(_ package: Package) -> String {
        let price = package.localizedPriceString
        guard package.packageType != .lifetime else { return price }
        return "\(price) per \(billingPeriod(package))"
    }

    private func subscriptionTitle(_ package: Package) -> String {
        switch package.packageType {
        case .annual:
            "blnd+ Annual Subscription"
        case .sixMonth:
            "blnd+ 6-Month Subscription"
        case .threeMonth:
            "blnd+ 3-Month Subscription"
        case .twoMonth:
            "blnd+ 2-Month Subscription"
        case .monthly:
            "blnd+ Monthly Subscription"
        case .weekly:
            "blnd+ Weekly Subscription"
        case .lifetime:
            "blnd+ Lifetime"
        case .unknown, .custom:
            "blnd+ Subscription"
        }
    }

    private func billingPeriod(_ package: Package) -> String {
        switch package.packageType {
        case .annual:
            "year"
        case .sixMonth:
            "6 months"
        case .threeMonth:
            "3 months"
        case .twoMonth:
            "2 months"
        case .monthly:
            "month"
        case .weekly:
            "week"
        case .lifetime:
            "lifetime"
        case .unknown, .custom:
            storeBillingPeriod(package) ?? "period"
        }
    }

    private func storeBillingPeriod(_ package: Package) -> String? {
        guard let period = package.storeProduct.subscriptionPeriod else { return nil }
        let unit: String
        switch period.unit {
        case .day:
            unit = period.value == 1 ? "day" : "days"
        case .week:
            unit = period.value == 1 ? "week" : "weeks"
        case .month:
            unit = period.value == 1 ? "month" : "months"
        case .year:
            unit = period.value == 1 ? "year" : "years"
        }
        guard period.value > 1 else { return unit }
        return "\(period.value) \(unit)"
    }

    // MARK: - Legal disclosures (App Store Review Guideline 3.1.2(c))

    private var legalSection: some View {
        VStack(spacing: 14) {
            Text(
                "Payment will be charged to your Apple ID account at confirmation of purchase. " +
                    "The subscription renews automatically unless canceled at least 24 hours " +
                    "before the end of the current period. Your account will be charged for " +
                    "renewal within 24 hours prior to the end of the current period. " +
                    "You can manage and cancel your subscription in Settings."
            )
            .font(.system(size: 12))
            .foregroundStyle(AppTheme.textDim)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 16) {
                Link(destination: termsURL) {
                    Text("Terms of Use")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(AppTheme.textMuted)
                        .underline()
                        .padding(.vertical, 8)
                        .padding(.horizontal, 4)
                }
                Text("·")
                    .font(.system(size: 12))
                    .foregroundStyle(AppTheme.textDim)
                Link(destination: privacyURL) {
                    Text("Privacy Policy")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(AppTheme.textMuted)
                        .underline()
                        .padding(.vertical, 8)
                        .padding(.horizontal, 4)
                }
            }
        }
    }

    private var restoreButton: some View {
        Button {
            Task { await restore() }
        } label: {
            if isRestoring {
                ProgressView()
                    .tint(AppTheme.textMuted)
            } else {
                Text("Restore Purchases")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(AppTheme.textMuted)
            }
        }
        .disabled(isRestoring)
    }

    // MARK: - Logic

    private func loadOffering() async {
        isLoadingOffering = true
        do {
            let offerings = try await Purchases.shared.offerings()
            offering = offerings.current
            if offerings.current?.availablePackages.isEmpty ?? true {
                print("PaywallView: offerings loaded but no packages available")
            }
        } catch {
            offering = nil
            print("PaywallView: failed to load offerings: \(error)")
        }
        isLoadingOffering = false
    }

    private func purchase(package: Package) async {
        isPurchasing = true
        do {
            let result = try await Purchases.shared.purchase(package: package)
            if !result.userCancelled {
                Analytics.subscriptionStarted(
                    productId: package.storeProduct.productIdentifier
                )
                didConvert = true
                await authState.fetchCurrentUser()
                dismiss()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
        isPurchasing = false
    }

    private func restore() async {
        isRestoring = true
        do {
            _ = try await Purchases.shared.restorePurchases()
            await authState.fetchCurrentUser()
            if authState.isPremium {
                Analytics.subscriptionRestored()
                didConvert = true
                dismiss()
            }
        } catch {
            errorMessage = "Could not restore purchases."
        }
        isRestoring = false
    }
}
