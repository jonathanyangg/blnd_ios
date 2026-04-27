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
                    offeringContent
                    legalSection
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

    @ViewBuilder
    private var offeringContent: some View {
        if isLoadingOffering {
            ProgressView()
                .tint(.white)
                .padding(.vertical, 28)
        } else if let pkg = offering?.monthly {
            purchaseSection(package: pkg)
        } else {
            unavailableSection
        }
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

    private func purchaseSection(package: Package) -> some View {
        VStack(spacing: 10) {
            Text("blnd+ Monthly Subscription · \(package.localizedPriceString) per month")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(AppTheme.textMuted)
                .multilineTextAlignment(.center)

            Button {
                Task { await purchase(package: package) }
            } label: {
                Group {
                    if isPurchasing {
                        ProgressView()
                            .tint(.black)
                    } else {
                        Text("Subscribe for \(package.localizedPriceString)/month")
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
    }

    // MARK: - Legal disclosures (App Store Review Guideline 3.1.2(c))

    private var legalSection: some View {
        VStack(spacing: 14) {
            Text(
                "Payment will be charged to your Apple ID account at confirmation of purchase. " +
                    "The subscription automatically renews each month unless it is canceled at " +
                    "least 24 hours before the end of the current period. Your account will be " +
                    "charged for renewal within 24 hours prior to the end of the current period. " +
                    "You can manage and cancel your subscription in your App Store account settings."
            )
            .font(.system(size: 11))
            .foregroundStyle(AppTheme.textDim)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 16) {
                Link(destination: URL(string: "https://blnd.movie/terms")!) {
                    Text("Terms of Use")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AppTheme.textMuted)
                        .underline()
                }
                Text("·")
                    .font(.system(size: 12))
                    .foregroundStyle(AppTheme.textDim)
                Link(destination: URL(string: "https://blnd.movie/privacy")!) {
                    Text("Privacy Policy")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AppTheme.textMuted)
                        .underline()
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
            if offering?.monthly == nil {
                print("PaywallView: offerings loaded but no monthly package available")
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
